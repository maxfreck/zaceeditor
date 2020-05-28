report zgui_ace_editor_test.

data editor type ref to zcl_gui_ace_editor.
data(log) = new zcl_itab_log( ).

module pbo0100 output.
  set pf-status '0100'.
  set titlebar '0100'.

  if editor is initial.
    editor = new #( parent = cl_gui_custom_container=>screen0 mode = 'abap'  logger = log ).
    editor->construct( ).

    data src_tab type standard table of abaptxt255.
    call function 'RPY_PROGRAM_READ'
      exporting
        program_name    = sy-cprog
      tables
        source_extended = src_tab.

    data(src) = reduce string( init s type string for l in src_tab next s = |{ s }{ l-line }{ cl_abap_char_utilities=>newline }| ).

    editor->set_textstream( src ).
  endif.
endmodule.

module pai0100 input.
  log->log( |PAI { sy-ucomm }| ).
  cl_gui_cfw=>flush( ).
  case sy-ucomm.
    when 'EXIT'.
      leave program.
    when 'ALERT'.
      log->show( ).
    when 'GET'.
      log->log( 'GET PAI start' ).
      log->log( 'GET PAI end:' ).
      cl_demo_output=>display_html( |<pre>{ editor->get_textstream( ) }</pre>| ).
  endcase.
endmodule.

start-of-selection.
  call screen 100.
