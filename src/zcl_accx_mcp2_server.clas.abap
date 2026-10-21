"! <p class="shorttext synchronized">Access Explorer: MCP server (mcp2 adapter)</p>
"! The only class that knows the mcp2 SDK. It maps neutral tool descriptors and
"! results to mcp2 and contains no business logic. The server profile is
"! '<area>/<server>' of the ZMCP2_SERVERS registration, so the class can be
"! registered several times with different profiles (see ZACCX_PROFILE).
"! Write tools return status confirmation_required with a stored plan: clients
"! that support form elicitation are asked to confirm it (the plan id travels
"! in requestState), other clients get the plan as text and must call again
"! with plan_id and confirm = true after the user approved it.
"! Run with F9 in ADT to register the default profile bc/access-support.
CLASS zcl_accx_mcp2_server DEFINITION PUBLIC CREATE PUBLIC
  INHERITING FROM zcl_mcp2_tool_server_base.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    CONSTANTS co_default_area   TYPE string VALUE `bc`.
    CONSTANTS co_default_server TYPE string VALUE `access-support`.
    "! input request key of the confirmation of a plan
    CONSTANTS co_confirm_key    TYPE string VALUE `confirm_plan`.

    METHODS zif_mcp2_server~get_name            REDEFINITION.
    METHODS zif_mcp2_server~get_version         REDEFINITION.
    METHODS zif_mcp2_server~get_title           REDEFINITION.
    METHODS zif_mcp2_server~get_description     REDEFINITION.
    METHODS zif_mcp2_server~get_instructions    REDEFINITION.
    METHODS zif_mcp2_server~check_authorization REDEFINITION.

  PROTECTED SECTION.
    METHODS define_tools REDEFINITION.
    METHODS call_tool    REDEFINITION.

  PRIVATE SECTION.
    DATA profile TYPE string.

    METHODS get_profile
      RETURNING VALUE(result) TYPE string.

    METHODS build_input_schema
      IMPORTING !descriptor   TYPE zif_accx_types=>ty_tool_descriptor
      RETURNING VALUE(result) TYPE REF TO zif_mcp2_ajson
      RAISING   zcx_mcp2_ajson_error.

    "! Answer of the user to a confirmation request: execute or cancel the plan
    METHODS answer_confirmation
      IMPORTING !request      TYPE REF TO zcl_mcp2_req_call_tool
      RETURNING VALUE(result) TYPE REF TO zif_mcp2_result
      RAISING   zcx_mcp2_error
                zcx_mcp2_ajson_error.

    "! Elicitation of the confirmation, if the client supports it; otherwise unbound
    METHODS ask_confirmation
      IMPORTING !tool_result  TYPE zif_accx_types=>ty_result
      RETURNING VALUE(result) TYPE REF TO zif_mcp2_result
      RAISING   zcx_mcp2_error
                zcx_mcp2_ajson_error.

    METHODS to_response
      IMPORTING !tool_result  TYPE zif_accx_types=>ty_result
      RETURNING VALUE(result) TYPE REF TO zif_mcp2_result
      RAISING   zcx_mcp2_ajson_error.

    METHODS compose_text
      IMPORTING !tool_result  TYPE zif_accx_types=>ty_result
      RETURNING VALUE(result) TYPE string.

ENDCLASS.

CLASS zcl_accx_mcp2_server IMPLEMENTATION.

  METHOD zif_mcp2_server~get_name.
    result = `accx`.
  ENDMETHOD.

  METHOD zif_mcp2_server~get_version.
    result = zif_accx_types=>co_release.
  ENDMETHOD.

  METHOD zif_mcp2_server~get_title.
    result = `Access Explorer`.
  ENDMETHOD.

  METHOD zif_mcp2_server~get_description.
    result = |Analysis of SAP users, roles and authorizations in system { sy-sysid }, client { sy-mandt }.|.
  ENDMETHOD.

  METHOD zif_mcp2_server~get_instructions.
    result = |Access Explorer (release { zif_accx_types=>co_release }) answers questions about SAP users, roles and | &&
             |authorizations in system { sy-sysid }, client { sy-mandt }. Results only contain data the calling user may | &&
             |display; hidden entries are counted, never silently dropped. Typical flow: get_user_profile for an overview | &&
             |of a user, then check_user_access to test whether the user may start a transaction or holds an | &&
             |authorization. Name the missing authorization object and field values precisely. Simulated failed checks | &&
             |also appear in the SU53 of the calling user. All tools are read-only except write tools (group ADMIN), | &&
             |which only appear in profiles that allow writing: they first return a plan; show it to the user and execute | &&
             |it (plan_id with confirm = true) only after the user explicitly approved exactly this plan - never on your | &&
             |own. Answer in the language of the question.|.
  ENDMETHOD.

  METHOD zif_mcp2_server~check_authorization.
    profile = to_lower( |{ area }/{ server }| ).
    TRY.
        result = zcl_accx_factory=>authorizer( profile )->check_endpoint( profile ).
      CATCH cx_root.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD define_tools.
    DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) ).
    LOOP AT zcl_accx_factory=>runtime( )->get_catalog( ctx ) INTO DATA(descriptor).
      APPEND VALUE #( name         = descriptor-name
                      title        = descriptor-title
                      description  = descriptor-description
                      input_schema = build_input_schema( descriptor )
                      annotations  = VALUE #( title                = descriptor-title
                                              read_only_hint       = descriptor-read_only
                                              destructive_hint     = descriptor-destructive
                                              destructive_hint_set = abap_true
                                              idempotent_hint      = descriptor-idempotent
                                              open_world_hint      = abap_false
                                              open_world_hint_set  = abap_true ) ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD call_tool.
    IF request->is_retry( ) = abap_true AND request->get_request_state( ) IS NOT INITIAL.
      result = answer_confirmation( request ).
      RETURN.
    ENDIF.
    DATA(args) = NEW zcl_accx_args_mcp2( request ).
    DATA(ctx) = zcl_accx_factory=>context( profile           = get_profile( )
                                           args              = args
                                           client_can_elicit = client_supports_elicitation( ) ).
    DATA(tool_result) = zcl_accx_factory=>runtime( )->execute( tool_name = request->get_name( )
                                                                args      = args
                                                                ctx       = ctx ).
    IF tool_result-status = zif_accx_types=>co_status-confirm.
      result = ask_confirmation( tool_result ).
    ENDIF.
    IF result IS NOT BOUND.
      result = to_response( tool_result ).
    ENDIF.
  ENDMETHOD.

  METHOD ask_confirmation.
    DATA(input) = NEW zcl_mcp2_input_elicitation( ).
    input->set_form( message          = |{ tool_result-confirmation-prompt }\n\nExecute this plan now?|
                     requested_schema = NEW zcl_mcp2_elicit_schema( )->add_boolean(
                                          name        = `confirm`
                                          title       = `Execute the change`
                                          description = |Plan { tool_result-confirmation-plan_id }, valid until | &&
                                                        |{ tool_result-confirmation-expires_at } UTC|
                                          default     = abap_false
                                          required    = abap_true ) ).
    IF can_request_input( input ) = abap_false.
      RETURN.
    ENDIF.
    result = input_required( request_key   = co_confirm_key
                             input         = input
                             request_state = tool_result-confirmation-plan_id ).
  ENDMETHOD.

  METHOD answer_confirmation.
    DATA(plan_id) = request->get_request_state( ).
    DATA(answer) = request->try_get_input_response( co_confirm_key ).
    IF answer IS BOUND AND answer->is_accept( ) = abap_true AND answer->get_boolean( `confirm` ) = abap_true.
      DATA(args) = NEW zcl_accx_args_map( ).
      args->set( name = zif_accx_types=>co_param-plan_id value = plan_id ).
      args->set( name = zif_accx_types=>co_param-confirm value = `true` ).
      DATA(ctx) = zcl_accx_factory=>context( profile = get_profile( ) args = args ).
      result = to_response( zcl_accx_factory=>runtime( )->execute( tool_name = request->get_name( )
                                                                    args      = args
                                                                    ctx       = ctx ) ).
      RETURN.
    ENDIF.
    " declined or cancelled: the plan of this user is withdrawn
    DATA(store) = zcl_accx_factory=>plan_store( ).
    DATA(plan) = store->get( plan_id ).
    IF plan-caller = sy-uname AND plan-state = zif_accx_plan_store=>co_state-open.
      store->close( plan_id = plan_id state = zif_accx_plan_store=>co_state-cancelled outcome = `not approved by the user` ).
      COMMIT WORK.
    ENDIF.
    result = zcl_mcp2_resp_call_tool=>text( |The user did not approve plan { plan_id }; nothing was changed.| ).
  ENDMETHOD.

  METHOD get_profile.
    result = COND #( WHEN profile IS NOT INITIAL THEN profile
                     ELSE |{ co_default_area }/{ co_default_server }| ).
  ENDMETHOD.

  METHOD build_input_schema.
    DATA(builder) = NEW zcl_mcp2_schema_builder( ).
    LOOP AT descriptor-params INTO DATA(param).
      CASE param-kind.
        WHEN zif_accx_types=>co_kind-integer.
          IF param-minimum <> 0 OR param-maximum <> 0.
            builder->add_integer( name        = param-name
                                  description = param-description
                                  required    = param-required
                                  minimum     = param-minimum
                                  maximum     = param-maximum ).
          ELSE.
            builder->add_integer( name = param-name description = param-description required = param-required ).
          ENDIF.
        WHEN zif_accx_types=>co_kind-number.
          builder->add_number( name = param-name description = param-description required = param-required ).
        WHEN zif_accx_types=>co_kind-boolean.
          builder->add_boolean( name = param-name description = param-description required = param-required ).
        WHEN zif_accx_types=>co_kind-string_list.
          builder->add_string_array( name = param-name description = param-description required = param-required ).
        WHEN OTHERS.
          IF param-enum IS NOT INITIAL.
            builder->add_string( name        = param-name
                                 description = param-description
                                 required    = param-required
                                 enum        = CONV #( param-enum ) ).
          ELSEIF param-maximum > 0.
            builder->add_string( name        = param-name
                                 description = param-description
                                 required    = param-required
                                 max_length  = param-maximum ).
          ELSE.
            builder->add_string( name = param-name description = param-description required = param-required ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
    result = builder->to_json( ).
  ENDMETHOD.

  METHOD to_response.
    FIELD-SYMBOLS <data> TYPE any.
    DATA response TYPE REF TO zcl_mcp2_resp_call_tool.
    DATA json     TYPE REF TO zif_mcp2_ajson.

    DATA(text) = compose_text( tool_result ).

    IF    tool_result-status = zif_accx_types=>co_status-denied
       OR tool_result-status = zif_accx_types=>co_status-invalid
       OR tool_result-status = zif_accx_types=>co_status-error.
      result = zcl_mcp2_resp_call_tool=>error_text( text ).
      RETURN.
    ENDIF.

    IF tool_result-data IS NOT BOUND.
      result = zcl_mcp2_resp_call_tool=>text( text ).
      RETURN.
    ENDIF.

    ASSIGN tool_result-data->* TO <data>.
    IF cl_abap_typedescr=>describe_by_data( <data> )->kind = cl_abap_typedescr=>kind_table.
      " structuredContent must be a JSON object
      json = zcl_mcp2_ajson=>create_empty( ).
      json->set( iv_path = `/rows` iv_val = <data> ).
      response = zcl_mcp2_resp_call_tool=>structured_json( json ).
    ELSE.
      response = zcl_mcp2_resp_call_tool=>structured_data( data = <data> add_text = abap_false ).
    ENDIF.
    response->add_text( text ).
    result = response.
  ENDMETHOD.

  METHOD compose_text.
    result = COND #( WHEN tool_result-summary IS NOT INITIAL THEN tool_result-summary ELSE |Status: { tool_result-status }| ).
    IF tool_result-status = zif_accx_types=>co_status-confirm OR tool_result-status = zif_accx_types=>co_status-partial.
      result = |Status: { tool_result-status }\n\n{ result }|.
    ENDIF.
    IF tool_result-warnings IS NOT INITIAL.
      result = |{ result }\n\nWarnings:|.
      LOOP AT tool_result-warnings INTO DATA(warning).
        result = |{ result }\n- { warning }|.
      ENDLOOP.
    ENDIF.
    IF tool_result-next_steps IS NOT INITIAL.
      result = |{ result }\n\nNext steps:|.
      LOOP AT tool_result-next_steps INTO DATA(next_step).
        result = |{ result }\n- { next_step }|.
      ENDLOOP.
    ENDIF.
    IF tool_result-sources IS NOT INITIAL.
      result = |{ result }\n\nSources: { concat_lines_of( table = tool_result-sources sep = `, ` ) }|.
    ENDIF.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    " the default profile and every profile maintained in ZACCX_PROFILE (area/server)
    DATA(profiles) = VALUE string_table( ( |{ co_default_area }/{ co_default_server }| ) ).
    SELECT profile FROM zaccx_profile INTO TABLE @DATA(configured).
    LOOP AT configured INTO DATA(entry).
      DATA(name) = to_lower( condense( CONV string( entry-profile ) ) ).
      IF name CA '/' AND NOT line_exists( profiles[ table_line = name ] ).
        APPEND name TO profiles.
      ENDIF.
    ENDLOOP.

    LOOP AT profiles INTO DATA(profile_name).
      SPLIT profile_name AT '/' INTO DATA(area) DATA(server).
      DATA(row) = VALUE zmcp2_servers( area = area server = server class = 'ZCL_ACCX_MCP2_SERVER' ).
      MODIFY zmcp2_servers FROM @row.
      out->write( |Access Explorer { zif_accx_types=>co_release }: registered { profile_name } - | &&
                  |endpoint POST /zmcp2/{ area }/{ server }?sap-client={ sy-mandt }| ).
      DATA(ctx) = zcl_accx_factory=>context( profile = profile_name ).
      out->write( |  Tools visible for { sy-uname }:| ).
      LOOP AT zcl_accx_factory=>runtime( )->get_catalog( ctx ) INTO DATA(descriptor).
        out->write( |  - { descriptor-name } ({ descriptor-group }{ COND #( WHEN descriptor-read_only = abap_false THEN `, WRITES` ) })| ).
      ENDLOOP.
      IF ctx->write_problem( ) IS NOT INITIAL.
        out->write( |  No write tools: { ctx->write_problem( ) }| ).
      ENDIF.
    ENDLOOP.
    COMMIT WORK.

    LOOP AT zcl_accx_factory=>registry( )->get_issues( ) INTO DATA(issue).
      out->write( |Plugin issue { issue-plugin_id }: { issue-message }| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
