unit OneAgentSDK.Native;

{
  Dynatrace OneAgent SDK for Delphi
  Low-level bindings to the C SDK shared library (onesdk_shared.dll).

  Calling convention: ONESDK_CALL on Windows = __stdcall, so all imports use stdcall.

  DLL selection:
    64-bit build: copy or add to PATH: ..\..\lib\windows-x86_64\onesdk_shared.dll
    32-bit build: copy or add to PATH: ..\..\lib\windows-x86_32\onesdk_shared.dll

  String encoding:
    All tracing strings use TOnesdk_string with ONESDK_CCSID_UTF16_LE (1203), which maps
    directly to Delphi's native UnicodeString on Windows (little-endian UTF-16). No conversion needed.
    MakeWStr builds a TOnesdk_string pointing into the Delphi string buffer; the string MUST
    remain alive (on the stack) for the duration of the SDK call.
}

{$ALIGN 8}

interface

const
  ONESDK_DLL = 'onesdk_shared.dll';

  // Result codes (onesdk_result_t = uint32_t on Windows)
  ONESDK_SUCCESS       = UInt32(0);
  ONESDK_ERROR_BASE    = UInt32($AFFE0000);
  ONESDK_ERROR_GENERIC = UInt32($AFFE0001);
  ONESDK_ERROR_NO_DATA = UInt32($AFFE000E); // = ONESDK_ERROR_BASE + 14

  // Handle sentinel
  ONESDK_INVALID_HANDLE = UInt64(0);

  // Agent state constants (from onesdk_common.h)
  ONESDK_AGENT_STATE_ACTIVE               = Int32(0);
  ONESDK_AGENT_STATE_TEMPORARILY_INACTIVE = Int32(1);
  ONESDK_AGENT_STATE_PERMANENTLY_INACTIVE = Int32(2);
  ONESDK_AGENT_STATE_NOT_INITIALIZED      = Int32(3);
  ONESDK_AGENT_STATE_ERROR                = Int32(-1);

  // Channel type constants (from onesdk_common.h)
  ONESDK_CHANNEL_TYPE_OTHER              = Int32(0);
  ONESDK_CHANNEL_TYPE_TCP_IP             = Int32(1);
  ONESDK_CHANNEL_TYPE_UNIX_DOMAIN_SOCKET = Int32(2);
  ONESDK_CHANNEL_TYPE_NAMED_PIPE         = Int32(3);
  ONESDK_CHANNEL_TYPE_IN_PROCESS         = Int32(4);

  // CCSID constants (from onesdk_string.h)
  ONESDK_CCSID_NULL     = UInt16(0);
  ONESDK_CCSID_ASCII    = UInt16(367);
  ONESDK_CCSID_UTF8     = UInt16(1209);
  ONESDK_CCSID_UTF16_LE = UInt16(1203); // native on Windows x86/x64 (little-endian UTF-16)

  // W3C trace context output buffer sizes including null terminator
  ONESDK_TRACE_ID_BUFFER_SIZE = 33; // 32 lowercase hex chars + null
  ONESDK_SPAN_ID_BUFFER_SIZE  = 17; // 16 lowercase hex chars + null

  // SDK stub version (from onesdk_version.h)
  ONESDK_STUB_VERSION_MAJOR = 1;
  ONESDK_STUB_VERSION_MINOR = 7;
  ONESDK_STUB_VERSION_PATCH = 1;

type
  PInt32 = ^Int32;   // Delphi does not provide this alias built-in

  TOnesdk_result_t              = UInt32;   // uint32_t on Windows
  TOnesdk_handle_t              = UInt64;   // onesdk_uint64_t
  TOnesdk_tracer_handle_t       = UInt64;
  TOnesdk_databaseinfo_handle_t = UInt64;

  // Maps to onesdk_string_t. Layout (64-bit): Pointer(8) + NativeUInt(8) + UInt16(2) + padding(6) = 24 bytes.
  // MUST match the C struct layout exactly. Do not pack.
  TOnesdk_string = record
    data        : Pointer;    // pointer to string data (may be nil for empty/null)
    byte_length : NativeUInt; // length of string data in bytes (not characters)
    ccsid       : UInt16;     // encoding; use ONESDK_CCSID_UTF16_LE for Delphi strings on Windows
  end;
  POnesdk_string = ^TOnesdk_string;

  TOnesdk_stub_version = record
    version_major : UInt32;
    version_minor : UInt32;
    version_patch : UInt32;
  end;

  // Callback types (called BY the C SDK, so they use cdecl)
  TOnesdk_agent_logging_callback = procedure(message: PAnsiChar); cdecl;
  TOnesdk_stub_logging_callback  = procedure(level: Int32; message: PWideChar); cdecl;

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

// Builds a TOnesdk_string pointing into a Delphi string's buffer using UTF-16 LE.
// The Delphi string MUST remain alive (referenced on the stack) for the duration
// of the SDK call that receives this TOnesdk_string.
procedure MakeWStr(out S: TOnesdk_string; const Value: string); inline;

// Builds a null-string (ccsid = ONESDK_CCSID_NULL) for optional parameters.
procedure MakeNullStr(out S: TOnesdk_string); inline;

// ---------------------------------------------------------------------------
// SDK imports — calling convention: stdcall (ONESDK_CALL on Windows = __stdcall)
// ---------------------------------------------------------------------------

// --- Initialization & shutdown ---
function  onesdk_initialize: TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_initialize@0' {$ENDIF};
function  onesdk_shutdown: TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_shutdown@0' {$ENDIF};
procedure onesdk_stub_get_version(out version: TOnesdk_stub_version); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_get_version@4' {$ENDIF};
procedure onesdk_stub_get_agent_load_info(agent_found: PInt32; agent_compatible: PInt32); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_get_agent_load_info@8' {$ENDIF};
function  onesdk_stub_set_logging_level(level: Int32): TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_set_logging_level@4' {$ENDIF};
procedure onesdk_stub_set_logging_callback(callback: TOnesdk_stub_logging_callback); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_set_logging_callback@4' {$ENDIF};

// Sets an SDK initialization variable BEFORE calling onesdk_initialize.
// AVar is a wide string in the form 'key=value', e.g. 'home=C:\oneagent'.
// AReplaceExisting: non-zero to overwrite an existing value, zero to keep existing.
function onesdk_stub_set_variable(AVar: PWideChar; AReplaceExisting: Int32): TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_set_variable@8' {$ENDIF};

// Clears all SDK initialization variables and releases memory.
procedure onesdk_stub_free_variables; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_stub_free_variables@0' {$ENDIF};

// --- Agent state & version ---
function onesdk_agent_get_current_state: Int32; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_agent_get_current_state@0' {$ENDIF};
function onesdk_agent_get_version_string: PWideChar; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_agent_get_version_string@0' {$ENDIF};
function onesdk_agent_set_warning_callback(callback: TOnesdk_agent_logging_callback): TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_agent_set_warning_callback@4' {$ENDIF};

// --- Common tracer lifecycle ---
procedure onesdk_tracer_start(tracer: TOnesdk_tracer_handle_t); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracer_start@8' {$ENDIF};
procedure onesdk_tracer_end(tracer: TOnesdk_tracer_handle_t); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracer_end@8' {$ENDIF};
// Sets error info on a tracer. error_class is optional (pass null-string if not available).
procedure onesdk_tracer_error_p(
  tracer        : TOnesdk_tracer_handle_t;
  error_class   : POnesdk_string;
  error_message : POnesdk_string); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracer_error_p@16' {$ENDIF};

// --- Tag propagation: outgoing (call after Start) ---
// Returns number of bytes copied. Pass buffer=nil and buffer_size=0 to query required size.
function onesdk_tracer_get_outgoing_dynatrace_string_tag(
  tracer               : TOnesdk_tracer_handle_t;
  buffer               : PAnsiChar;
  buffer_size          : NativeUInt;
  required_buffer_size : PNativeUInt): NativeUInt; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracer_get_outgoing_dynatrace_string_tag@20' {$ENDIF};

// --- Tag propagation: incoming (call before Start) ---
procedure onesdk_tracer_set_incoming_dynatrace_string_tag_p(
  tracer     : TOnesdk_tracer_handle_t;
  string_tag : POnesdk_string); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracer_set_incoming_dynatrace_string_tag_p@12' {$ENDIF};

// --- Custom request attributes ---
procedure onesdk_customrequestattribute_add_integers_p(
  keys   : POnesdk_string;
  values : PInt64;
  count  : NativeUInt); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_customrequestattribute_add_integers_p@12' {$ENDIF};

procedure onesdk_customrequestattribute_add_floats_p(
  keys   : POnesdk_string;
  values : PDouble;
  count  : NativeUInt); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_customrequestattribute_add_floats_p@12' {$ENDIF};

procedure onesdk_customrequestattribute_add_strings_p(
  keys   : POnesdk_string;
  values : POnesdk_string;
  count  : NativeUInt); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_customrequestattribute_add_strings_p@12' {$ENDIF};

// --- Custom service tracer ---
function onesdk_customservicetracer_create_p(
  service_method : POnesdk_string;
  service_name   : POnesdk_string): TOnesdk_tracer_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_customservicetracer_create_p@8' {$ENDIF};

// --- Outgoing remote call tracer ---
function onesdk_outgoingremotecalltracer_create_p(
  service_method   : POnesdk_string;
  service_name     : POnesdk_string;
  service_endpoint : POnesdk_string;
  channel_type     : Int32;
  channel_endpoint : POnesdk_string): TOnesdk_tracer_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingremotecalltracer_create_p@20' {$ENDIF};

// Optional; must be called before Start.
procedure onesdk_outgoingremotecalltracer_set_protocol_name_p(
  tracer        : TOnesdk_tracer_handle_t;
  protocol_name : POnesdk_string); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingremotecalltracer_set_protocol_name_p@12' {$ENDIF};

// --- Incoming remote call tracer ---
function onesdk_incomingremotecalltracer_create_p(
  service_method   : POnesdk_string;
  service_name     : POnesdk_string;
  service_endpoint : POnesdk_string): TOnesdk_tracer_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_incomingremotecalltracer_create_p@12' {$ENDIF};

// Optional; must be called before Start.
procedure onesdk_incomingremotecalltracer_set_protocol_name_p(
  tracer        : TOnesdk_tracer_handle_t;
  protocol_name : POnesdk_string); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_incomingremotecalltracer_set_protocol_name_p@12' {$ENDIF};

// --- Database info & tracer ---
function onesdk_databaseinfo_create_p(
  name             : POnesdk_string;
  vendor           : POnesdk_string;
  channel_type     : Int32;
  channel_endpoint : POnesdk_string): TOnesdk_databaseinfo_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_databaseinfo_create_p@16' {$ENDIF};

procedure onesdk_databaseinfo_delete(
  databaseinfo: TOnesdk_databaseinfo_handle_t); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_databaseinfo_delete@8' {$ENDIF};

function onesdk_databaserequesttracer_create_sql_p(
  databaseinfo : TOnesdk_databaseinfo_handle_t;
  statement    : POnesdk_string): TOnesdk_tracer_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_databaserequesttracer_create_sql_p@12' {$ENDIF};

procedure onesdk_databaserequesttracer_set_returned_row_count(
  tracer    : TOnesdk_tracer_handle_t;
  row_count : Int32); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_databaserequesttracer_set_returned_row_count@12' {$ENDIF};

procedure onesdk_databaserequesttracer_set_round_trip_count(
  tracer           : TOnesdk_tracer_handle_t;
  round_trip_count : Int32); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_databaserequesttracer_set_round_trip_count@12' {$ENDIF};

// --- Outgoing web request tracer ---
function onesdk_outgoingwebrequesttracer_create_p(
  url    : POnesdk_string;
  method : POnesdk_string): TOnesdk_tracer_handle_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingwebrequesttracer_create_p@8' {$ENDIF};

procedure onesdk_outgoingwebrequesttracer_add_request_headers_p(
  tracer : TOnesdk_tracer_handle_t;
  names  : POnesdk_string;
  values : POnesdk_string;
  count  : NativeUInt); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingwebrequesttracer_add_request_headers_p@20' {$ENDIF};

procedure onesdk_outgoingwebrequesttracer_add_response_headers_p(
  tracer : TOnesdk_tracer_handle_t;
  names  : POnesdk_string;
  values : POnesdk_string;
  count  : NativeUInt); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingwebrequesttracer_add_response_headers_p@20' {$ENDIF};

procedure onesdk_outgoingwebrequesttracer_set_status_code(
  tracer      : TOnesdk_tracer_handle_t;
  status_code : Int32); stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_outgoingwebrequesttracer_set_status_code@12' {$ENDIF};

// --- W3C Trace Context ---
// Returns ONESDK_SUCCESS when a valid PurePath node is active, ONESDK_ERROR_NO_DATA otherwise.
// Buffers must be at least ONESDK_TRACE_ID_BUFFER_SIZE / ONESDK_SPAN_ID_BUFFER_SIZE bytes.
function onesdk_tracecontext_get_current(
  trace_id_buffer      : PAnsiChar;
  trace_id_buffer_size : NativeUInt;
  span_id_buffer       : PAnsiChar;
  span_id_buffer_size  : NativeUInt): TOnesdk_result_t; stdcall; external ONESDK_DLL {$IFDEF CPUX86} name '_onesdk_tracecontext_get_current@16' {$ENDIF};

implementation

procedure MakeWStr(out S: TOnesdk_string; const Value: string);
begin
  S.ccsid := ONESDK_CCSID_UTF16_LE;
  if Value = '' then
  begin
    S.data        := nil;
    S.byte_length := 0;
  end
  else
  begin
    S.data        := PWideChar(Value);
    S.byte_length := NativeUInt(Length(Value)) * 2;
  end;
end;

procedure MakeNullStr(out S: TOnesdk_string);
begin
  S.data        := nil;
  S.byte_length := 0;
  S.ccsid       := ONESDK_CCSID_NULL;
end;

end.
