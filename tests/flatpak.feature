Feature: Flatpak
  Scenario: External changes to flatpak installations should cause appcenter to update
    * Make sure that io.elementary.appcenter is running
    * Wait for the spinner to stop
    * Wait for command "flatpak install --user -y flathub com.github.tchx84.Flatseal"
    * Wait for the spinner to stop
    * Wait for command "io.elementary.appcenter appstream://com.github.tchx84.Flatseal"
    * Uninstall button is visible
    * Press back
    * Wait for command "flatpak remove --user -y com.github.tchx84.Flatseal"
    * Wait for the spinner to stop
    * Wait for command "io.elementary.appcenter appstream://com.github.tchx84.Flatseal"
    * Uninstall button is not visible
