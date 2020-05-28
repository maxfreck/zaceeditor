class zcl_gui_ace_editor definition public create public inheriting from cl_gui_html_viewer.
  public section.
    methods constructor
      importing
        value(parent) type ref to cl_gui_container
        mode          type string default 'javascript'
        theme         type string default 'eclipse'
        logger        type ref to  zcl_itab_log
      exceptions
        cntl_error
        cntl_install_error
        dp_install_error
        dp_error.

    methods construct.
    methods set_textstream importing src type string.
    methods get_textstream returning value(ret) type string.

  protected section.
    data:
      log            type ref to zcl_itab_log,
      loaded         type abap_bool value abap_false,
      content_buffer type string,

      ace_mode       type string,
      ace_theme      type string.

    methods preload_files.

    methods frontend_eval importing script type string.
    methods get_sapdata returning value(ret) type string.
    methods cut_data_from_url importing src type string returning value(ret) type string.
    methods is_last_chunk importing chunk type string returning value(ret) type abap_bool.

  private section.
    data uri type text1024.

    methods on_sapevent for event sapevent of cl_gui_html_viewer importing action frame getdata postdata sender query_table.
    methods handle_dom_content_loaded.

endclass.



class zcl_gui_ace_editor implementation.
  method constructor.
    call method super->constructor
      exporting
        parent             = parent
        uiflag             = ( uiflag_noiemenu + uiflag_no3dborder )
      exceptions
        cntl_error         = 1
        cntl_install_error = 2
        dp_install_error   = 3
        dp_error           = 4.
    case sy-subrc.
      when 1.
        raise cntl_error.
      when 2.
        raise cntl_install_error.
      when 3.
        raise dp_install_error.
      when 4.
        raise dp_error.
    endcase.

    log = logger.
    ace_mode = mode.
    ace_theme = theme.
  endmethod.

  method construct.
    set handler on_sapevent for me.

    data lt_events type cntl_simple_events.
    append value #( eventid = m_id_sapevent appl_event = abap_true ) to lt_events.
    set_registered_events( events = lt_events ).

    preload_files( ).
    show_url( exporting url = 'editor.html' ).
  endmethod.

  method preload_files.
    select objid, value from wwwparams into table @data(files)
     where relid = 'MI'
       and objid like 'ZCL_GUI_ACE_EDITOR%'
       and name = 'filename'.

    data dummy_url type text80.
    loop at files assigning field-symbol(<file>).
      call method load_mime_object
        exporting
          object_id            = <file>-objid
          object_url           = <file>-value
        importing
          assigned_url         = dummy_url
        exceptions
          object_not_found     = 1
          dp_invalid_parameter = 2
          dp_error_general     = 3
          others               = 4.
    endloop.

    call method load_mime_object
      exporting
        object_id            = 'ZSAPGUILOGGER'
        object_url           = 'sapguilogger.js'
      importing
        assigned_url         = dummy_url
      exceptions
        object_not_found     = 1
        dp_invalid_parameter = 2
        dp_error_general     = 3
        others               = 4.

  endmethod.

  method frontend_eval.
    set_script( cl_bcs_convert=>string_to_soli( script ) ).
    execute_script( exceptions dp_error = 1 cntl_error = 2 ).

    if sy-subrc <> 0.
      raise exception type zcx_html_ui exporting text = |Failed to run frontend script with exit code { sy-subrc }|.
    endif.
  endmethod.

  method get_sapdata.
    data:
      base64full type string,
      base64     type string.

    clear uri.
    cl_gui_cfw=>flush( ).
    frontend_eval( 'sapguiData.rewind();' ).
    cl_gui_cfw=>flush( ).
    get_current_url( importing url = uri ).
    cl_gui_cfw=>flush( ).

    cl_demo_output=>write_data( uri ).

    data(chunks) = conv i( cut_data_from_url( conv #( uri ) ) ).
    cl_demo_output=>write_data( chunks ).

    do chunks times.
      frontend_eval( 'sapguiData.next();' ).
      cl_gui_cfw=>flush( ).
      get_current_url( importing url = uri ).
      cl_gui_cfw=>flush( ).
      cl_demo_output=>write_data( uri ).

      clear base64.
      base64 = cut_data_from_url( conv #( uri ) ).
      base64full = base64full && base64.
    enddo.


    cl_demo_output=>write_data( base64full ).
    ret = cl_http_utility=>decode_utf8( cl_http_utility=>decode_x_base64( base64full ) ).
  endmethod.

  method cut_data_from_url.
    data:
      i type i,
      j type i.

    find first occurrence of '#' in src match offset i.
    if i = 0.
      return.
    endif.

    i = i + 1.
    j = strlen( src ) - i.
    ret = substring( val = src off = i len = j ).
  endmethod.

  method is_last_chunk.
    data(len) = strlen( chunk ).

    if len = 0 or ( len >= 1 and substring( val = chunk off = ( len - 1 ) len = 1 ) = '=' ).
      ret = abap_true.
      return.
    endif.

    ret = abap_false.
  endmethod.

  method on_sapevent.
    log->log( |Received action { action }| ).
    case action.
      when 'DOMContentLoaded'.
        handle_dom_content_loaded( ).
    endcase.
  endmethod.

  method handle_dom_content_loaded.
    frontend_eval(
      |window.editor.setTheme("ace/theme/{ ace_theme }");\n| &&
      |window.editor.session.setMode("ace/mode/{ ace_mode }");\n|
    ).
    loaded = abap_true.
    if content_buffer is not initial.
      set_textstream( content_buffer ).
      clear content_buffer.
    endif.
  endmethod.

  method set_textstream.
    if loaded = abap_false.
      content_buffer = src.
      return.
    endif.

    data(contents) = src.
    replace all occurrences of '"' in contents with '\"'.
    replace all occurrences of |\r| in contents with ''.
    replace all occurrences of |\n| in contents with '\n'.

    frontend_eval( |window.editor.setRawContent("{ contents }")| ).

  endmethod.

  method get_textstream.
    frontend_eval( 'window.editor.syncToBakend()' ).
    ret = get_sapdata( ).
  endmethod.
endclass.
