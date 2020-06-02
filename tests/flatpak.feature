Feature: Flatpak
  Scenario: External changes to flatpak installations should cause appcenter to update
    * Make sure that io.elementary.appcenter is running
    * Wait for the spinner to stop
    * Wait for command "flatpak install --user -y flathub com.github.tchx84.Flatseal"
    * Wait for the spinner to stop
    * Wait for command "io.elementary.appcenter appstream://com.github.tchx84.Flatseal"
    Then "Uninstall" button is visible
    * Press back
    * Wait for command "flatpak remove --user -y com.github.tchx84.Flatseal"
    * Wait for the spinner to stop
    * Wait for command "io.elementary.appcenter appstream://com.github.tchx84.Flatseal"
    Then "Uninstall" button is not visible

  Scenario: Non-curated dialog appears for flatpak installs
    * Make sure that io.elementary.appcenter is running
    * Click "Free" button
    Then Non-curated dialog is open
    * Click "Don’t Install" button
    Then "Free" button is visible
    Then Non-curated dialog is not open

  Scenario: Accepting the non-curated dialog installs the app
    * Make sure that io.elementary.appcenter is running
    * Click "Free" button
    Then Non-curated dialog is open
    * Click "Install Anyway" button
    * Wait for the spinner to stop
    Then "Uninstall" button is visible

  Scenario: The non-curated dialog can be permanently dismissed
    * Make sure that io.elementary.appcenter is running
    * Click "Uninstall" button
    * Wait for the spinner to stop
    * Click "Free" button
    Then Non-curated dialog is open
    * Click "Show non-curated warnings" check box
    * Click "Install Anyway" button
    * Wait for the spinner to stop
    * Click "Uninstall" button
    * Wait for the spinner to stop
    * Click "Free" button
    * Wait for the spinner to stop
    Then Non-curated dialog is not open
