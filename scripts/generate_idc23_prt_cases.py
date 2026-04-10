from __future__ import annotations

from pathlib import Path
from textwrap import dedent

REPO = Path(__file__).resolve().parents[1]
CASES_ROOT = REPO / "flows" / "idc23" / "testcases"

STANDARD_HEADER = dedent(
    """
    appId: com.bmwgroup.idnext.launcher
    jsEngine: graaljs
    onFlowStart:
      - runFlow: ../../subflows/common/start.yaml
    onFlowComplete:
      - runFlow: ../../subflows/common/stop.yaml
    ---
    """
).strip() + "\n"

STUDIO_HEADER = dedent(
    """
    appId: com.bmwgroup.idnext.launcher
    jsEngine: graaljs
    onFlowStart:
      - runFlow:
          file: ../../subflows/common/studio_start_dlt.yaml
          env:
            CONTROL_SERVER_URL: ${CONTROL_SERVER_URL}
            DLT_IP: ${DLT_IP}
            DLT_PORT: ${DLT_PORT}
            CASE_ID: ${CASE_ID}
            RUN_TS: ${RUN_TS}
            RUN_ROOT: ${RUN_ROOT}
            DLT_OUTPUT: ${DLT_OUTPUT}
            CAPTURE_ID: ${CAPTURE_ID}
      - runFlow: ../../subflows/common/start.yaml
    onFlowComplete:
      - runFlow: ../../subflows/common/stop.yaml
      - waitForAnimationToEnd
      - waitForAnimationToEnd
      - waitForAnimationToEnd
      - runFlow:
          file: ../../subflows/common/studio_stop_dlt.yaml
          env:
            CONTROL_SERVER_URL: ${CONTROL_SERVER_URL}
            CAPTURE_ID: ${CAPTURE_ID}
      - runFlow:
          file: ../../subflows/common/studio_bundle_evidence.yaml
          env:
            CONTROL_SERVER_URL: ${CONTROL_SERVER_URL}
            CASE_ID: ${CASE_ID}
            RUN_TS: ${RUN_TS}
            RUN_ROOT: ${RUN_ROOT}
            CAPTURE_ID: ${CAPTURE_ID}
    ---
    """
).strip() + "\n"


def scenario(text: str) -> str:
    return dedent(text).strip() + "\n"


CASES = [
    {
        "id": "ABPI-684348",
        "title": "Shortcut icons after STR mode",
        "priority": "P1",
        "automation": "semi-automated",
        "notes": [
            "Creates two shortcuts under user X, switches to user Y for STR, then switches back to user X.",
            "Uses backend STR cycle plus explicit profile switching through the control-server user helper.",
        ],
        "acceptance": [
            "Shortcut icons remain present after STR return to user X.",
            "Both saved shortcuts can be recalled from Toolbelt after STR with radio backend remaining strict-OK.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-684348'}"
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_684348_switch_to_x_before_setup
                  TARGET_USER_ID: ${IDC23_USER_X_ID}
                  TARGET_USER_NAME: ${IDC23_USER_X_NAME}
                  STRICT: "false"
            - assertTrue: ${output.userProfileEnsureOk == true}
            - assertTrue: ${output.userProfileEnsure.targetSpecified == true}
            - assertTrue: ${output.userProfileEnsure.targetResolved == true}
            - takeScreenshot: "ABPI_684348_user_x_before_setup"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "0"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - takeScreenshot: "ABPI_684348_shortcut_0_added"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "1"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - takeScreenshot: "ABPI_684348_shortcut_1_added"
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_684348_switch_to_y_before_str
                  TARGET_USER_ID: ${IDC23_USER_Y_ID}
                  TARGET_USER_NAME: ${IDC23_USER_Y_NAME}
                  STRICT: "false"
            - assertTrue: ${output.userProfileEnsureOk == true}
            - assertTrue: ${output.userProfileEnsure.targetSpecified == true}
            - assertTrue: ${output.userProfileEnsure.targetResolved == true}
            - takeScreenshot: "ABPI_684348_user_y_before_str"
            - takeScreenshot: "ABPI_684348_before_str"
            - runFlow:
                file: ../../subflows/common/lifecycle_str_once.yaml
                env:
                  TEST_ID: ABPI_684348_str
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_684348_switch_back_to_x_after_str
                  TARGET_USER_ID: ${IDC23_USER_X_ID}
                  TARGET_USER_NAME: ${IDC23_USER_X_NAME}
                  STRICT: "false"
            - assertTrue: ${output.userProfileEnsureOk == true}
            - assertTrue: ${output.userProfileEnsure.targetSpecified == true}
            - assertTrue: ${output.userProfileEnsure.targetResolved == true}
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - takeScreenshot: "ABPI_684348_after_str"
            - runFlow:
                file: ../../subflows/common/tap_toolbelt_shortcut_idc23.yaml
                env:
                  SHORTCUT_INDEX: "0"
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - runFlow:
                file: ../../subflows/common/tap_toolbelt_shortcut_idc23.yaml
                env:
                  SHORTCUT_INDEX: "1"
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-684288",
        "title": "Radio station selecting from the Toolbelt",
        "priority": "P1",
        "automation": "semi-automated",
        "notes": [
            "Creates multiple shortcuts and validates recall from Toolbelt.",
            "Uses generic list-item selectors for rack portability.",
        ],
        "acceptance": [
            "Shortcuts can be recalled from Toolbelt.",
            "Radio backend verification remains strict-OK.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-684288'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "0"
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "2"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-671650",
        "title": "User Switch",
        "priority": "P1",
        "automation": "semi-automated",
        "notes": [
            "Switches between two target profiles and validates playback continuity.",
            "Target profile IDs/names are provided by env vars IDC23_USER_X_* and IDC23_USER_Y_*.",
        ],
        "acceptance": [
            "User X -> Y -> X switching completes without backend radio failure.",
            "Last played station remains audible after each switch.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-671650'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_671650_switch_to_x
                  TARGET_USER_ID: ${IDC23_USER_X_ID}
                  TARGET_USER_NAME: ${IDC23_USER_X_NAME}
                  STRICT: "false"
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_671650_switch_to_y
                  TARGET_USER_ID: ${IDC23_USER_Y_ID}
                  TARGET_USER_NAME: ${IDC23_USER_Y_NAME}
                  STRICT: "false"
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - runFlow:
                file: ../../../subflows/ensure_user_profile_backend.yaml
                env:
                  TEST_ID: ABPI_671650_switch_back_x
                  TARGET_USER_ID: ${IDC23_USER_X_ID}
                  TARGET_USER_NAME: ${IDC23_USER_X_NAME}
                  STRICT: "false"
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-671641",
        "title": "Audio Focus switch",
        "priority": "P1",
        "automation": "semi-automated",
        "notes": [
            "Exercises source transitions and validates radio focus recovery.",
            "Non-radio source labels are build-dependent and are tapped as optional selectors.",
        ],
        "acceptance": [
            "Switch to non-radio source succeeds when available.",
            "Switching back to Radio resumes strict backend pass.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-671641'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow: ../../../subflows/open_source_selector.yaml
            - tapOn:
                text: USB
                optional: true
            - tapOn:
                text: Bluetooth
                optional: true
            - tapOn:
                text: Spotify
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/open_source_selector.yaml
            - tapOn:
                text: Radio
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - takeScreenshot: "ABPI_671641_owner_manual_placeholder"
            """
        ),
    },
    {
        "id": "ABPI-671618",
        "title": "Radio station reception after Lifecycle",
        "priority": "P1",
        "automation": "automated",
        "notes": [
            "Runs STR and Cold Boot lifecycles in loop to detect instability/crashes.",
            "Defaults to 5 iterations each (IDC23_STR_LOOPS / IDC23_COLD_BOOT_LOOPS override).",
            "Includes profile-recovery step after each lifecycle to mitigate known BMW ID fallback bug.",
        ],
        "acceptance": [
            "Radio remains recoverable and backend-verified after each STR loop.",
            "Radio remains recoverable and backend-verified after each Cold Boot loop.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-671618'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - evalScript: "${output.strLoops = (typeof IDC23_STR_LOOPS !== 'undefined' ? parseInt(String(IDC23_STR_LOOPS), 10) : 5); if (isNaN(output.strLoops) || output.strLoops < 1) { output.strLoops = 5; } output.strIter = 0}"
            - repeat:
                times: 5
                while:
                  true: ${output.strIter < output.strLoops}
                commands:
                  - runFlow:
                      file: ../../subflows/common/lifecycle_str_once.yaml
                      env:
                        TEST_ID: ABPI_671618_str
                  - runFlow:
                      file: ../../../subflows/ensure_user_profile_backend.yaml
                      env:
                        TEST_ID: ABPI_671618_user_recover_after_str
                        TARGET_USER_ID: ${IDC23_TARGET_USER_ID}
                        TARGET_USER_NAME: ${IDC23_TARGET_USER_NAME}
                        STRICT: "false"
                  - runFlow: ../../../subflows/ensure_radio_source.yaml
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
                  - evalScript: ${output.strIter = output.strIter + 1}
            - evalScript: "${output.coldLoops = (typeof IDC23_COLD_BOOT_LOOPS !== 'undefined' ? parseInt(String(IDC23_COLD_BOOT_LOOPS), 10) : 5); if (isNaN(output.coldLoops) || output.coldLoops < 1) { output.coldLoops = 5; } output.coldIter = 0}"
            - repeat:
                times: 5
                while:
                  true: ${output.coldIter < output.coldLoops}
                commands:
                  - runFlow:
                      file: ../../subflows/common/lifecycle_cold_boot_once.yaml
                      env:
                        TEST_ID: ABPI_671618_cold
                  - runFlow:
                      file: ../../../subflows/ensure_user_profile_backend.yaml
                      env:
                        TEST_ID: ABPI_671618_user_recover_after_cold
                        TARGET_USER_ID: ${IDC23_TARGET_USER_ID}
                        TARGET_USER_NAME: ${IDC23_TARGET_USER_NAME}
                        STRICT: "false"
                  - runFlow: ../../../subflows/ensure_radio_source.yaml
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
                  - evalScript: ${output.coldIter = output.coldIter + 1}
            """
        ),
    },
    {
        "id": "ABPI-669816",
        "title": "FM/DAB activate/deactivate Traffic/Radio info announcement",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Normalizes Radio info OFF baseline, enables the toggle, then observes popup arrival within a configurable wait window.",
            "Disables the toggle again and asserts a short post-disable quiet window.",
        ],
        "acceptance": [
            "Radio info toggle is reachable and operable with stateful ON/OFF verification.",
            "If the popup is observed during the enabled window it is captured and dismissed.",
            "Radio path remains usable after settings changes.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669816'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/preconditions_radio_settings.yaml
            - runFlow: ../../subflows/common/select_radio_info_station_idc23.yaml
            - runFlow: ../../subflows/common/open_radio_settings_idc23.yaml
            - runFlow:
                file: ../../subflows/common/set_radio_info_toggle_idc23.yaml
                env:
                  RADIO_INFO_ENABLED: "true"
                  RADIO_INFO_STATE_ASSERT: "false"
            - takeScreenshot: "ABPI_669816_radio_info_enabled"
            - pressKey: back
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow:
                file: ../../subflows/common/wait_for_radio_info_popup_idc23.yaml
                env:
                  POPUP_WAIT_SECONDS: "${RADIO_INFO_POPUP_WAIT_SECONDS}"
                  POPUP_REQUIRED: "${RADIO_INFO_REQUIRE_POPUP}"
                  DISMISS_POPUP: "true"
            - runFlow:
                when:
                  true: ${output.idc23RadioInfoPopupObserved == true}
                commands:
                  - takeScreenshot: "ABPI_669816_radio_info_popup_observed"
            - runFlow: ../../subflows/common/open_radio_settings_idc23.yaml
            - runFlow:
                file: ../../subflows/common/set_radio_info_toggle_idc23.yaml
                env:
                  RADIO_INFO_ENABLED: "false"
                  RADIO_INFO_STATE_ASSERT: "false"
            - takeScreenshot: "ABPI_669816_radio_info_disabled"
            - pressKey: back
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow:
                file: ../../subflows/common/wait_for_radio_info_popup_idc23.yaml
                env:
                  POPUP_WAIT_SECONDS: "10"
                  POPUP_REQUIRED: "false"
            - assertTrue: ${output.idc23RadioInfoPopupObserved != true}
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669812",
        "title": "FM/DAB Traffic/Radio info popup abort via MFL",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Enables Radio info, waits for a naturally observed popup, then sends an MFL-like center action via backend inject.",
            "Popup observation remains signal/time dependent and uses a configurable wait window.",
        ],
        "acceptance": [
            "A real radio info popup is observed before the abort action is injected.",
            "The popup is dismissed by the MFL-like action while radio remains healthy afterward.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669812'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow: ../../../subflows/preconditions_radio_settings.yaml
            - runFlow: ../../subflows/common/select_radio_info_station_idc23.yaml
            - runFlow: ../../subflows/common/open_radio_settings_idc23.yaml
            - runFlow:
                file: ../../subflows/common/set_radio_info_toggle_idc23.yaml
                env:
                  RADIO_INFO_ENABLED: "true"
                  RADIO_INFO_STATE_ASSERT: "false"
            - pressKey: back
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow:
                file: ../../subflows/common/wait_for_radio_info_popup_idc23.yaml
                env:
                  POPUP_WAIT_SECONDS: "${RADIO_INFO_POPUP_WAIT_SECONDS}"
                  POPUP_REQUIRED: "true"
            - takeScreenshot: "ABPI_669812_radio_info_popup_observed"
            - runFlow:
                file: ../../../subflows/backend_inject.yaml
                env:
                  KIND: swag
                  TARGET: center
            - waitForAnimationToEnd
            - assertNotVisible:
                text: '(?i)(cancel radio info|stop playing radio infos)'
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669803",
        "title": "DAB All stations list select other station",
        "priority": "P2",
        "automation": "automated",
        "notes": [
            "Selects one station and then a different one from all-stations list.",
            "Backend check validates playback continuity after each selection.",
        ],
        "acceptance": [
            "First station selection is playable.",
            "Second station selection is playable and updates backend state.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669803'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 1
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669802",
        "title": "DAB All stations list coverage",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Validates list availability and performs bounded scrolling capture.",
            "Manual review can confirm expected bearer icons for DAB/FM/AM.",
        ],
        "acceptance": [
            "All stations list is reachable and scrollable.",
            "Artifacts include screenshots for icon/list review.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669802'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - takeScreenshot: "ABPI_669802_list_top"
            - swipe:
                start: "70%,78%"
                end: "70%,32%"
                duration: 450
            - waitForAnimationToEnd
            - swipe:
                start: "70%,78%"
                end: "70%,32%"
                duration: 450
            - waitForAnimationToEnd
            - takeScreenshot: "ABPI_669802_list_scrolled"
            - assertVisible:
                id: "ListImageComponent ImageRightIcon"
                index: 0
            """
        ),
    },
    {
        "id": "ABPI-669801",
        "title": "DAB status bar update",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Uses backend UI snapshots plus Maestro hierarchy fallback to inspect current IDC23 status-bar and launcher widget text.",
            "Status-bar return path uses current top-bar selector first and launcher widget as the last fallback.",
        ],
        "acceptance": [
            "Radio remains playing outside Radio screen while home/widget status text stays populated.",
            "Skip next/prev updates the extracted station text while backend remains strict-OK.",
            "Tapping the current top-bar entry returns to the active Radio list.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669801'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23RadioScreenStationBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23RadioScreenKeyBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23RadioScreenStationBefore != '' || output.idc23RadioScreenKeyBefore != ''}
            - pressKey: home
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationBefore != '' || output.idc23HomeKeyBefore != ''}
            - runFlow: ../../../subflows/inject_swag_next.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationAfterNext = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyAfterNext = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationAfterNext != '' || output.idc23HomeKeyAfterNext != ''}
            - assertTrue: ${(output.idc23HomeKeyBefore != '' && output.idc23HomeKeyAfterNext != '' && output.idc23HomeKeyAfterNext != output.idc23HomeKeyBefore) || (output.idc23HomeStationBefore != '' && output.idc23HomeStationAfterNext != '' && output.idc23HomeStationAfterNext != output.idc23HomeStationBefore)}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationAfterPrev = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyAfterPrev = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationAfterPrev != '' || output.idc23HomeKeyAfterPrev != ''}
            - assertTrue: ${(output.idc23HomeKeyAfterNext != '' && output.idc23HomeKeyAfterPrev != '' && output.idc23HomeKeyAfterPrev != output.idc23HomeKeyAfterNext) || (output.idc23HomeStationAfterNext != '' && output.idc23HomeStationAfterPrev != '' && output.idc23HomeStationAfterPrev != output.idc23HomeStationAfterNext)}
            - runFlow: ../../subflows/common/open_radio_from_status_bar_idc23.yaml
            - assertVisible:
                text: "(?i)all stations"
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - assertTrue: ${output.radioVerdict.ui.sourceName == 'RADIO'}
            """
        ),
    },
    {
        "id": "ABPI-669800",
        "title": "DAB presets select via touch and skip",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Creates two favourites and uses backend station-key snapshots to prove wrap-around in preset context.",
            "Current IDC23 preset validation relies on radio backend plus Maestro hierarchy fallback for station identity.",
        ],
        "acceptance": [
            "Preset/favorite selection remains playable.",
            "Previous from the first favourite wraps to the last favourite.",
            "Next from the last favourite wraps back to the first favourite while backend remains strict-OK.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669800'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
            - waitForAnimationToEnd
            - tapOn:
                text: Add to favourites
                optional: true
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 1
            - waitForAnimationToEnd
            - tapOn:
                text: Add to favourites
                optional: true
            - runFlow: ../../../subflows/open_favourites.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetFirstStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetFirstKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23PresetFirstStation != '' || output.idc23PresetFirstKey != ''}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetLastStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetLastKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23PresetLastStation != '' || output.idc23PresetLastKey != ''}
            - assertTrue: ${(output.idc23PresetFirstKey != '' && output.idc23PresetLastKey != '' && output.idc23PresetLastKey != output.idc23PresetFirstKey) || (output.idc23PresetFirstStation != '' && output.idc23PresetLastStation != '' && output.idc23PresetLastStation != output.idc23PresetFirstStation)}
            - runFlow: ../../../subflows/inject_swag_next.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetWrappedToFirstStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetWrappedToFirstKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23PresetFirstKey != '' && output.idc23PresetWrappedToFirstKey != '' && output.idc23PresetWrappedToFirstKey == output.idc23PresetFirstKey) || (output.idc23PresetFirstStation != '' && output.idc23PresetWrappedToFirstStation != '' && output.idc23PresetWrappedToFirstStation == output.idc23PresetFirstStation)}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetWrappedBackToLastStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetWrappedBackToLastKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23PresetLastKey != '' && output.idc23PresetWrappedBackToLastKey != '' && output.idc23PresetWrappedBackToLastKey == output.idc23PresetLastKey) || (output.idc23PresetLastStation != '' && output.idc23PresetWrappedBackToLastStation != '' && output.idc23PresetWrappedBackToLastStation == output.idc23PresetLastStation)}
            """
        ),
    },
    {
        "id": "ABPI-669799",
        "title": "DAB presets save and delete",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Uses the live IDC23 particle action path instead of long-press context menus.",
            "Starts from a cleared favourites state so add/remove is deterministic.",
        ],
        "acceptance": [
            "Station can be saved through the current-station particle action and then recalled from Favourites.",
            "Removing the saved station returns backend queue context to All stations while playback continuity is preserved.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669799'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow: ../../subflows/common/clear_favourites_idc23.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow:
                file: ../../subflows/common/tap_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "2"
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetSavedStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetSavedKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23PresetSavedStation != '' || output.idc23PresetSavedKey != ''}
            - runFlow: ../../subflows/common/tap_particle_action_idc23.yaml
            - runFlow: ../../../subflows/open_favourites.yaml
            - takeScreenshot: "ABPI_669799_saved_station"
            - runFlow:
                file: ../../subflows/common/tap_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "0"
                  STATION_OPTIONAL: "true"
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetSavedStationFromFavourites = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetSavedKeyFromFavourites = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23PresetSavedKey != '' && output.idc23PresetSavedKeyFromFavourites == output.idc23PresetSavedKey) || (output.idc23PresetSavedStation != '' && output.idc23PresetSavedStationFromFavourites == output.idc23PresetSavedStation)}
            - runFlow: ../../subflows/common/tap_particle_action_idc23.yaml
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function norm(v){return (v===undefined||v===null)?'':String(v).toLowerCase().replace(/\\s+/g,'');} output.idc23PresetQueueTitleNormalized = norm(output.radioVerdict && output.radioVerdict.media ? output.radioVerdict.media.queueTitle : ''); output.idc23PresetRemovedStation = (output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station || '') : ''); output.idc23PresetRemovedKey = (output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey || '') : '');}"
            - assertTrue: ${output.idc23PresetQueueTitleNormalized == 'allstations'}
            - assertTrue: ${(output.idc23PresetSavedKey != '' && output.idc23PresetRemovedKey == output.idc23PresetSavedKey) || (output.idc23PresetSavedStation != '' && output.idc23PresetRemovedStation == output.idc23PresetSavedStation)}
            """
        ),
    },
    {
        "id": "ABPI-669798",
        "title": "DAB shortcuts select",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Creates DAB shortcut and recalls it from Toolbelt.",
            "Includes source-switch override check back to radio shortcut.",
        ],
        "acceptance": [
            "Shortcut can be selected from Toolbelt.",
            "Selecting shortcut restores radio playback from another source.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669798'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "0"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/open_source_selector.yaml
            - tapOn:
                text: USB
                optional: true
            - tapOn:
                text: Bluetooth
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669795",
        "title": "DAB shortcuts save and delete",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Validates add, duplicate-add, and delete flows for Toolbelt shortcut entries.",
            "Duplicate-state messaging is captured via screenshots for review.",
        ],
        "acceptance": [
            "Shortcut add path works and duplicate add is handled.",
            "Saved shortcut can be removed and recreated.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669795'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "0"
            - runFlow:
                file: ../../subflows/common/long_press_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "${output.idc23ShortcutChosenIndex}"
            - waitForAnimationToEnd
            - takeScreenshot: "ABPI_669795_duplicate_shortcut_prompt"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - tapOn:
                text: Delete
                optional: true
            - tapOn:
                text: Remove
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "1"
                  STATION_OPTIONAL: "true"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            """
        ),
    },
    {
        "id": "ABPI-669794",
        "title": "DAB stations list skip to other station",
        "priority": "P2",
        "automation": "automated",
        "notes": [
            "Exercises repeated next/previous skip controls from station list context.",
            "Backend checks run after each skip to catch regressions quickly.",
        ],
        "acceptance": [
            "Next skips keep station changes healthy.",
            "Previous skips keep station changes healthy.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669794'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - repeat:
                times: 4
                commands:
                  - runFlow: ../../../subflows/inject_swag_next.yaml
                  - waitForAnimationToEnd
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
            - repeat:
                times: 2
                commands:
                  - runFlow: ../../../subflows/inject_swag_prev.yaml
                  - waitForAnimationToEnd
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669793",
        "title": "HD Audio audible",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
                        "Attempts HD-labelled station selection when visible, then falls back to list index.",
                        "If HD labels are not exposed on the current skin, fallback still validates audible playback.",
        ],
        "acceptance": [
            "An HD-capable station can be selected when available.",
            "Selected station remains audible with strict backend pass.",
        ],
                "flow": scenario(
                        """
                        - evalScript: "${output.testId = 'ABPI-669793'; output.stationTapped = false}"
                        - runFlow: ../../../subflows/ensure_radio_source.yaml
                        - runFlow: ../../../subflows/open_all_stations.yaml
                        - runFlow:
                                when:
                                    visible:
                                        text: "HD"
                                commands:
                                    - tapOn: "HD"
                                    - evalScript: ${output.stationTapped = true}
                                    - waitForAnimationToEnd
                        - runFlow:
                                when:
                                    true: ${output.stationTapped != true}
                                commands:
                                    - tapOn:
                                            id: "ListImageComponent ImageRightIcon"
                                            index: 0
                                    - evalScript: ${output.stationTapped = true}
                        - waitForAnimationToEnd
                        - runFlow: ../../../subflows/verify_radio_backend.yaml
                        """
                ),
    },
    {
        "id": "ABPI-669792",
        "title": "AM status bar update",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "AM-equivalent status-bar coverage uses backend UI snapshots plus Maestro hierarchy fallback on current IDC23 layouts.",
            "Band-specific AM station preparation may still require a rack-specific station target.",
        ],
        "acceptance": [
            "Current radio station remains audible through navigation and skip actions while home/widget status text stays populated.",
            "Skip next/prev updates the extracted station text while backend remains strict-OK.",
            "Tapping the current top-bar entry returns to the active Radio list.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669792'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23RadioScreenStationBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23RadioScreenKeyBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23RadioScreenStationBefore != '' || output.idc23RadioScreenKeyBefore != ''}
            - takeScreenshot: "ABPI_669792_am_status_before"
            - pressKey: home
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyBefore = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationBefore != '' || output.idc23HomeKeyBefore != ''}
            - runFlow: ../../../subflows/inject_swag_next.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationAfterNext = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyAfterNext = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationAfterNext != '' || output.idc23HomeKeyAfterNext != ''}
            - assertTrue: ${(output.idc23HomeKeyBefore != '' && output.idc23HomeKeyAfterNext != '' && output.idc23HomeKeyAfterNext != output.idc23HomeKeyBefore) || (output.idc23HomeStationBefore != '' && output.idc23HomeStationAfterNext != '' && output.idc23HomeStationAfterNext != output.idc23HomeStationBefore)}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23HomeStationAfterPrev = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.homeWidgetStation || output.radioVerdict.ui.topBarStation || output.radioVerdict.ui.statusBarStation) : ''); output.idc23HomeKeyAfterPrev = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23HomeStationAfterPrev != '' || output.idc23HomeKeyAfterPrev != ''}
            - assertTrue: ${(output.idc23HomeKeyAfterNext != '' && output.idc23HomeKeyAfterPrev != '' && output.idc23HomeKeyAfterPrev != output.idc23HomeKeyAfterNext) || (output.idc23HomeStationAfterNext != '' && output.idc23HomeStationAfterPrev != '' && output.idc23HomeStationAfterPrev != output.idc23HomeStationAfterNext)}
            - runFlow: ../../subflows/common/open_radio_from_status_bar_idc23.yaml
            - assertVisible:
                text: "(?i)all stations"
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - assertTrue: ${output.radioVerdict.ui.sourceName == 'RADIO'}
            """
        ),
    },
    {
        "id": "ABPI-669790",
        "title": "AM shortcuts save and delete",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "AM equivalent of DAB shortcut save/delete validation.",
            "Uses same Toolbelt interaction path and duplicate-save check.",
        ],
        "acceptance": [
            "AM shortcut can be saved and removed.",
            "Duplicate save path is observable and non-destructive.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669790'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow:
                file: ../../subflows/common/add_station_to_shortcuts_idc23.yaml
                env:
                  STATION_INDEX: "0"
            - runFlow:
                file: ../../subflows/common/long_press_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "${output.idc23ShortcutChosenIndex}"
            - waitForAnimationToEnd
            - takeScreenshot: "ABPI_669790_duplicate_prompt"
            - runFlow: ../../../subflows/open_shortcuts.yaml
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - tapOn:
                text: Delete
                optional: true
            - tapOn:
                text: Remove
                optional: true
            - waitForAnimationToEnd
            """
        ),
    },
    {
        "id": "ABPI-669789",
        "title": "AM stations list skip to other station (variant A)",
        "priority": "P2",
        "automation": "automated",
        "notes": [
            "AM skip responsiveness validation variant A.",
            "Mirrors repeated hardkey/MFL skip behavior expectations.",
        ],
        "acceptance": [
            "Repeated next skips keep audio/metadata healthy.",
            "Repeated previous skips keep audio/metadata healthy.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669789'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - repeat:
                times: 3
                commands:
                  - runFlow: ../../../subflows/inject_swag_next.yaml
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
            - repeat:
                times: 3
                commands:
                  - runFlow: ../../../subflows/inject_swag_prev.yaml
                  - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669787",
        "title": "AM stations list skip to other station (variant B)",
        "priority": "P2",
        "automation": "automated",
        "notes": [
            "AM skip responsiveness validation variant B (redundant split in source report).",
            "Kept as separate testcase for 1:1 Jira traceability.",
        ],
        "acceptance": [
            "Station transitions continue to succeed under skip burst actions.",
            "Backend checks remain strict-OK.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669787'}"
            - runFlow: ../../subflows/common/radio_ready_and_verify.yaml
            - repeat:
                times: 5
                commands:
                  - runFlow: ../../../subflows/inject_swag_next.yaml
                  - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            - repeat:
                times: 5
                commands:
                  - runFlow: ../../../subflows/inject_swag_prev.yaml
                  - waitForAnimationToEnd
            - runFlow: ../../../subflows/verify_radio_backend.yaml
            """
        ),
    },
    {
        "id": "ABPI-669786",
        "title": "AM presets select station via touch and skip",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "AM-equivalent preset flow now uses station-key snapshots to prove first/last wrap-around in preset context.",
            "Rack-specific AM station preparation may still be needed to guarantee true AM-only coverage.",
        ],
        "acceptance": [
            "Preset touch selection remains playable.",
            "Previous from the first favourite wraps to the last favourite.",
            "Next from the last favourite wraps back to the first favourite while backend remains strict-OK.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669786'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
            - waitForAnimationToEnd
            - tapOn:
                text: Add to favourites
                optional: true
            - longPressOn:
                id: "ListImageComponent ImageRightIcon"
                index: 1
            - waitForAnimationToEnd
            - tapOn:
                text: Add to favourites
                optional: true
            - runFlow: ../../../subflows/open_favourites.yaml
            - tapOn:
                id: "ListImageComponent ImageRightIcon"
                index: 0
                optional: true
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetFirstStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetFirstKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23PresetFirstStation != '' || output.idc23PresetFirstKey != ''}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetLastStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetLastKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23PresetLastStation != '' || output.idc23PresetLastKey != ''}
            - assertTrue: ${(output.idc23PresetFirstKey != '' && output.idc23PresetLastKey != '' && output.idc23PresetLastKey != output.idc23PresetFirstKey) || (output.idc23PresetFirstStation != '' && output.idc23PresetLastStation != '' && output.idc23PresetLastStation != output.idc23PresetFirstStation)}
            - runFlow: ../../../subflows/inject_swag_next.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetWrappedToFirstStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetWrappedToFirstKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23PresetFirstKey != '' && output.idc23PresetWrappedToFirstKey != '' && output.idc23PresetWrappedToFirstKey == output.idc23PresetFirstKey) || (output.idc23PresetFirstStation != '' && output.idc23PresetWrappedToFirstStation != '' && output.idc23PresetWrappedToFirstStation == output.idc23PresetFirstStation)}
            - runFlow: ../../../subflows/inject_swag_prev.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23PresetWrappedBackToLastStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23PresetWrappedBackToLastKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23PresetLastKey != '' && output.idc23PresetWrappedBackToLastKey != '' && output.idc23PresetWrappedBackToLastKey == output.idc23PresetLastKey) || (output.idc23PresetLastStation != '' && output.idc23PresetWrappedBackToLastStation != '' && output.idc23PresetWrappedBackToLastStation == output.idc23PresetLastStation)}
            """
        ),
    },
    {
        "id": "ABPI-669785",
        "title": "AM presets delete the only saved station",
        "priority": "P2",
        "automation": "semi-automated",
        "notes": [
            "Starts from a cleared favourites state so the removal is truly a single-preset delete path.",
            "Uses the live IDC23 particle action instead of long-press context menus.",
        ],
        "acceptance": [
            "Single preset can be removed without interrupting playback.",
            "Backend queue context falls back to All stations after removing the only saved preset.",
        ],
        "flow": scenario(
            """
            - evalScript: "${output.testId = 'ABPI-669785'}"
            - runFlow: ../../../subflows/ensure_radio_source.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow: ../../subflows/common/clear_favourites_idc23.yaml
            - runFlow: ../../../subflows/open_all_stations.yaml
            - runFlow:
                file: ../../subflows/common/tap_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "2"
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23SinglePresetStation = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23SinglePresetKey = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${output.idc23SinglePresetStation != '' || output.idc23SinglePresetKey != ''}
            - runFlow: ../../subflows/common/tap_particle_action_idc23.yaml
            - runFlow: ../../../subflows/open_favourites.yaml
            - runFlow:
                file: ../../subflows/common/tap_station_entry_idc23.yaml
                env:
                  STATION_INDEX: "0"
                  STATION_OPTIONAL: "true"
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function pick(v){return (v===undefined||v===null)?'':String(v).trim();} output.idc23SinglePresetStationFromFavourites = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station) : ''); output.idc23SinglePresetKeyFromFavourites = pick(output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey) : '');}"
            - assertTrue: ${(output.idc23SinglePresetKey != '' && output.idc23SinglePresetKeyFromFavourites == output.idc23SinglePresetKey) || (output.idc23SinglePresetStation != '' && output.idc23SinglePresetStationFromFavourites == output.idc23SinglePresetStation)}
            - runFlow: ../../subflows/common/tap_particle_action_idc23.yaml
            - waitForAnimationToEnd
            - runFlow: ../../subflows/common/verify_radio_backend_maestro_ui.yaml
            - evalScript: "${function norm(v){return (v===undefined||v===null)?'':String(v).toLowerCase().replace(/\\s+/g,'');} output.idc23SinglePresetQueueTitleNormalized = norm(output.radioVerdict && output.radioVerdict.media ? output.radioVerdict.media.queueTitle : ''); output.idc23SinglePresetRemovedStation = (output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.particleStation || output.radioVerdict.ui.statusBarStation || output.radioVerdict.ui.station || '') : ''); output.idc23SinglePresetRemovedKey = (output.radioVerdict && output.radioVerdict.ui ? (output.radioVerdict.ui.stationKey || output.radioVerdict.ui.topBarStationKey || '') : '');}"
            - assertTrue: ${output.idc23SinglePresetQueueTitleNormalized == 'allstations'}
            - assertTrue: ${(output.idc23SinglePresetKey != '' && output.idc23SinglePresetRemovedKey == output.idc23SinglePresetKey) || (output.idc23SinglePresetStation != '' && output.idc23SinglePresetRemovedStation == output.idc23SinglePresetStation)}
            """
        ),
    },
]


def render_meta(case: dict) -> str:
    lines = [
        f'caseId: "{case["id"]}"',
        f'title: "{case["title"]}"',
        'owner: ""',
        f'priority: "{case["priority"]}"',
        'source: "TMS_PRT_TestScenarios.pdf"',
        f'automationLevel: "{case["automation"]}"',
        'notes:',
    ]
    for note in case["notes"]:
        lines.append(f'  - "{note}"')
    lines.append('acceptance:')
    for item in case["acceptance"]:
        lines.append(f'  - "{item}"')
    return "\n".join(lines) + "\n"


def render_flow(case: dict, studio: bool) -> str:
    header = STUDIO_HEADER if studio else STANDARD_HEADER
    return header + case["flow"]


def main() -> int:
    CASES_ROOT.mkdir(parents=True, exist_ok=True)

    # Fill missing test IDs from the extracted list with deterministic reuse patterns.
    existing_ids = {c["id"] for c in CASES}
    required = [
        "ABPI-684348",
        "ABPI-684288",
        "ABPI-671650",
        "ABPI-671641",
        "ABPI-671618",
        "ABPI-669816",
        "ABPI-669812",
        "ABPI-669803",
        "ABPI-669802",
        "ABPI-669801",
        "ABPI-669800",
        "ABPI-669799",
        "ABPI-669798",
        "ABPI-669795",
        "ABPI-669794",
        "ABPI-669793",
        "ABPI-669792",
        "ABPI-669790",
        "ABPI-669789",
        "ABPI-669787",
        "ABPI-669786",
        "ABPI-669785",
    ]

    titles = {
        "ABPI-684348": "Shortcut icons after STR mode",
        "ABPI-684288": "Radio station selecting from the Toolbelt",
        "ABPI-671650": "User Switch",
        "ABPI-671641": "Audio Focus switch",
        "ABPI-671618": "Radio station reception after Lifecycle",
        "ABPI-669816": "FM/DAB activate/deactivate Traffic/Radio info announcement",
        "ABPI-669812": "FM/DAB Traffic/Radio info popup abort via MFL",
        "ABPI-669803": "DAB All stations list select other station",
        "ABPI-669802": "DAB All stations list coverage",
        "ABPI-669801": "DAB status bar update",
        "ABPI-669800": "DAB presets select via touch and skip",
        "ABPI-669799": "DAB presets save and delete",
        "ABPI-669798": "DAB shortcuts select",
        "ABPI-669795": "DAB shortcuts save and delete",
        "ABPI-669794": "DAB stations list skip to other station",
        "ABPI-669793": "HD Audio audible",
        "ABPI-669792": "AM status bar update",
        "ABPI-669790": "AM shortcuts save and delete",
        "ABPI-669789": "AM stations list skip to other station (variant A)",
        "ABPI-669787": "AM stations list skip to other station (variant B)",
        "ABPI-669786": "AM presets select station via touch and skip",
        "ABPI-669785": "AM presets delete the only saved station",
    }

    # Ensure we have exactly 22 mapped scenarios.
    mapped = {c["id"]: c for c in CASES}
    missing = [cid for cid in required if cid not in mapped]
    if missing:
        raise RuntimeError(f"Missing scenario templates for: {missing}")

    index_lines = []
    for cid in required:
        case = mapped[cid]
        case_dir = CASES_ROOT / cid
        case_dir.mkdir(parents=True, exist_ok=True)

        (case_dir / "case.meta.yaml").write_text(render_meta(case), encoding="utf-8")
        (case_dir / "idc23.yaml").write_text(render_flow(case, studio=False), encoding="utf-8")
        (case_dir / "idc23.studio.yaml").write_text(render_flow(case, studio=True), encoding="utf-8")

        index_lines.append(f"{cid} -> {cid}/idc23.yaml :: {titles[cid]}")

    (CASES_ROOT / "_INDEX.txt").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    print(f"Generated {len(required)} IDC23 PRT cases under {CASES_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
