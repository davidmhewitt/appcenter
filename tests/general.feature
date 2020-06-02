Feature: General

  Background:
    * Make sure that io.elementary.appcenter is running

  Scenario: Search should be focused and editable at the correct times
    # Immediately after opening AppCenter
    Then Search is focused
    Then Search is editable
    * Open installed tab
    Then Search is not editable
    * Open home tab
    Then Search is editable
    * Open Accessories category
    Then Search is editable
    * Press Down key
    Then Search is not focused
    Then Search is editable
    * Press key combination <Ctrl><F>
    Then Search is focused
    * Press Down key
    * Press Enter key
    Then Search is not editable
    * Press back
    Then Search is editable
    * Press back
    Then Search is editable

  Scenario: Quit AppCenter via shortcut
    * Quit AppCenter
    Then AppCenter is not running
