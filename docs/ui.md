# UI

## Overview
- Mode = activity = profile, extension = capability = feature
- **Mode**: named collection of configured (parameters set) extensions
    - Examples: indoor mode, outdoor navigation mode (no text detection; short scene descriptions), document reading mode (text detection - language, skew correction - confidence interval), etc.

## Idea
- Set of users with a set of named modes (main modes below + outdoor navigation, document reading, etc.)
- Each mode contains a set of capabilities/extensions (document reading: text detection capability)
- Each extension can be configured with different parameters & some will require user consent forms

## Page Structure
- Mode library/manager/editor/previewer
- Capability library/manager/editor/previewer/documentation
- Research study library/manager/documentation

## Required Capabilities
- Manage available modes:
    - Can create named modes and preview, edit, & view their documentation
    - Can switch modes quickly
- For a given mode: can edit/delete/see documentation for each extension
- Preview mode:
    - From mode manager or mode editor
    - Opens prebuilt interactive tutorial to help users understand capabilities of all extensions in mode
- Preview extension:
    - From mode editor or extension library or extension documentation page
    - Opens prebuilt interactive tutorial of that extension
- Extension documentation page:
    - Can tweak parameters and add into current activity profile
    - Can add directly with default settings from extension library
- Researching: framework for researchers to publish uneditable profiles that have participant enrollment and informed consent with data collection disclosure
    - Data collection capability with toggles for available data streams
    - Canonical consent and enrollment framework that’s customizable
- App contribution: add extension with documentation page and tutorial

## Detailed UI Notes

### Modes
- **Mode library/browser** (home/main/landing page?): holds all publicly available (canonical + community-contributed) modes
    - Video preview with docked tabs at bottom or menu icon in top corner
    - Switch quickly through modes: 3 finger swipe or arrow icons on each side
    - Selecting publicly available mode opens **mode documentation** page
        - Mode previewer: can preview default mode with given extensions and parameters
        - Download/plus button that installs mode; then available in mode manager
    - “Manage modes” button navigates to mode manager page
- **Mode manager**: lists user’s installed available modes; can add mode from public library, build mode from scratch, edit existing modes
    - Can create new mode > kicked into mode editor
    - Can edit and delete existing modes > kicked into mode editor
    - Can reorder existing modes
    - Can activate mode as default mode to use
    - Can preview entire mode (without activating it as current mode)
    - From mode manager/editor: can preview entire current mode or given extension with its setting
- **Mode editor**: shows mode’s name & lists all extensions in mode with their current parameter settings
    - Can create new mode
    - Can edit existing mode (with buttons to save changes or cancel):
        - Change mode’s name
        - Add new extension into mode
        - Delete an extension from mode
        - Change an extension’s parameter
    - Can preview an extension

### Extensions
- **Extension library/browser**: high level summary of list of available extensions
    - Can navigate to extension documentation page by clicking to see more details about each extension
    - Can download extensions if not downloaded
    - Can add extensions to modes with default parameters
- **Extension documentation page**: detailed documentation with text & video
    - Longer form text about extension
    - Preview extension: opens prebuilt interactive tutorial of extension with default parameters in extension library/browser that user can engage with; using just that extension
    - Change some extension parameters and preview; can then add extensions to modes with tweaked parameters
    - Click “add extension to current mode:” returns user to mode editor with that extension added into extension list for that mode with its default parameters

### Research
- **Study library**: browse available studies to enroll in
- **Study manager**: view, leave, activate study profiles; view previous studies
    - Open research **study documentation** page

## Database
- A set of modes with
    - A user
    - A set of extensions
- A set of extensions with
    - A mode
    - A set of parameters
- A set of parameters with
    - A name
    - A value (number, boolean, etc.)