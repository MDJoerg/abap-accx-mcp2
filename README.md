# abap-accx-mcp2

*[Deutsch](#deutsch) below.*

Transport adapter of [Access Explorer (ACCX)](https://github.com/MDJoerg/abap-accx-base) for the
[abap-ai/mcp2](https://github.com/abap-ai/mcp2) MCP SDK. ABAP package `ZACCX_MCP2`.

The adapter is a **variant**: it maps the neutral tools, prompts and resources of ACCX to the
mcp2 SDK (endpoint `/zmcp2/<area>/<server>`, registration table `ZMCP2_SERVERS`) and contains
no business logic. Use it, or its sibling [abap-accx-mcp1](https://github.com/MDJoerg/abap-accx-mcp1)
for the older SDK. Both can be installed side by side.

## Install

1. Install the mcp2 SDK and install **abap-accx-base** (package `ZACCX`).
2. Pull this repository into package `ZACCX_MCP2` with abapGit.
3. Run class `ZCL_ACCX_MCP2_SERVER` with F9 in ADT. It registers `bc/access-support` and every
   profile of table `ZACCX_PROFILE` in `ZMCP2_SERVERS` and lists the visible tools.
4. Connect your MCP client to `https://<host>/zmcp2/bc/access-support?sap-client=<client>`.

Run step 3 again after you have added a profile.

Everything else (tools, profiles, security, user guide, architecture, how the packages fit
together) is documented in **[abap-accx-base](https://github.com/MDJoerg/abap-accx-base)**.

## Deutsch

Transport-Adapter von [Access Explorer (ACCX)](https://github.com/MDJoerg/abap-accx-base) für das
MCP-SDK [abap-ai/mcp2](https://github.com/abap-ai/mcp2). ABAP-Paket `ZACCX_MCP2`.

Der Adapter ist eine **Variante**: Er bildet die neutralen Tools, Prompts und Ressourcen von ACCX
auf das mcp2-SDK ab (Endpunkt `/zmcp2/<area>/<server>`, Registrierungstabelle `ZMCP2_SERVERS`)
und enthält keine Fachlogik. Nutzen Sie ihn oder seinen Bruder
[abap-accx-mcp1](https://github.com/MDJoerg/abap-accx-mcp1) für das ältere SDK. Beide können
nebeneinander installiert werden.

### Installation

1. mcp2-SDK und **abap-accx-base** (Paket `ZACCX`) installieren.
2. Dieses Repository mit abapGit in das Paket `ZACCX_MCP2` ziehen.
3. Klasse `ZCL_ACCX_MCP2_SERVER` in ADT mit F9 ausführen. Sie trägt `bc/access-support` und jedes
   Profil der Tabelle `ZACCX_PROFILE` in `ZMCP2_SERVERS` ein und listet die sichtbaren Tools.
4. Den MCP-Client mit `https://<host>/zmcp2/bc/access-support?sap-client=<mandant>` verbinden.

Schritt 3 nach dem Anlegen eines Profils wiederholen.

Alles Weitere (Tools, Profile, Sicherheit, Benutzerhandbuch, Architektur, Zusammenspiel der
Pakete) steht in **[abap-accx-base](https://github.com/MDJoerg/abap-accx-base)**.
