"! <p class="shorttext synchronized">Access Explorer: tool arguments from mcp2 request</p>
"! Thin wrapper - no copying of the request arguments.
CLASS zcl_accx_args_mcp2 DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_accx_args.

    METHODS constructor
      IMPORTING !request TYPE REF TO zcl_mcp2_req_call_tool.

  PRIVATE SECTION.
    DATA request TYPE REF TO zcl_mcp2_req_call_tool.

ENDCLASS.

CLASS zcl_accx_args_mcp2 IMPLEMENTATION.

  METHOD constructor.
    me->request = request.
  ENDMETHOD.

  METHOD zif_accx_args~has.
    result = request->has_arg( name ).
  ENDMETHOD.

  METHOD zif_accx_args~get_string.
    result = request->get_arg_string_or( name = name default_value = default ).
  ENDMETHOD.

  METHOD zif_accx_args~get_integer.
    result = request->get_arg_integer_or( name = name default_value = default ).
  ENDMETHOD.

  METHOD zif_accx_args~get_boolean.
    result = request->get_arg_boolean_or( name = name default_value = default ).
  ENDMETHOD.

  METHOD zif_accx_args~get_strings.
    TRY.
        result = request->get_arg_string_table( name ).
      CATCH zcx_mcp2_ajson_error.
        CLEAR result.
    ENDTRY.
    " tolerate a single string where a list is expected
    IF result IS INITIAL AND request->has_arg( name ) = abap_true.
      DATA(single) = request->get_arg_string_or( name = name default_value = `` ).
      IF single IS NOT INITIAL.
        APPEND single TO result.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD zif_accx_args~get_names.
    DATA(arguments) = request->get_arguments( ).
    IF arguments IS BOUND.
      result = arguments->members( `/` ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
