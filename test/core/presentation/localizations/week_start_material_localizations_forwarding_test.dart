// The deprecated reorder getters are forwarded too, so they are checked too.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/localizations/week_start_material_localizations.dart';

/// Issue #4232: [WeekStartMaterialLocalizations] changes the week start and
/// answers every other member exactly as the localizations it wraps.
///
/// One line per member, so a member forwarded to the wrong getter fails by
/// name. Run in German, whose strings differ from the English defaults
/// Flutter's abstract class falls back to.
void main() {
  test('forwards every other member unchanged', () async {
    const locale = Locale('de');
    final base = await GlobalMaterialLocalizations.delegate.load(locale);
    final wrapped = WeekStartMaterialLocalizations(base, DateTime.sunday);
    final date = DateTime(2026, 11, 6);

    expect(wrapped.firstDayOfWeekIndex, 0);
    expect(base.firstDayOfWeekIndex, 1);

    expect(
      wrapped.openAppDrawerTooltip,
      base.openAppDrawerTooltip,
      reason: 'openAppDrawerTooltip',
    );
    expect(
      wrapped.backButtonTooltip,
      base.backButtonTooltip,
      reason: 'backButtonTooltip',
    );
    expect(
      wrapped.clearButtonTooltip,
      base.clearButtonTooltip,
      reason: 'clearButtonTooltip',
    );
    expect(
      wrapped.closeButtonTooltip,
      base.closeButtonTooltip,
      reason: 'closeButtonTooltip',
    );
    expect(
      wrapped.deleteButtonTooltip,
      base.deleteButtonTooltip,
      reason: 'deleteButtonTooltip',
    );
    expect(
      wrapped.moreButtonTooltip,
      base.moreButtonTooltip,
      reason: 'moreButtonTooltip',
    );
    expect(
      wrapped.nextMonthTooltip,
      base.nextMonthTooltip,
      reason: 'nextMonthTooltip',
    );
    expect(
      wrapped.previousMonthTooltip,
      base.previousMonthTooltip,
      reason: 'previousMonthTooltip',
    );
    expect(
      wrapped.firstPageTooltip,
      base.firstPageTooltip,
      reason: 'firstPageTooltip',
    );
    expect(
      wrapped.lastPageTooltip,
      base.lastPageTooltip,
      reason: 'lastPageTooltip',
    );
    expect(
      wrapped.nextPageTooltip,
      base.nextPageTooltip,
      reason: 'nextPageTooltip',
    );
    expect(
      wrapped.previousPageTooltip,
      base.previousPageTooltip,
      reason: 'previousPageTooltip',
    );
    expect(
      wrapped.showMenuTooltip,
      base.showMenuTooltip,
      reason: 'showMenuTooltip',
    );
    expect(
      wrapped.aboutListTileTitle('Submersion'),
      base.aboutListTileTitle('Submersion'),
      reason: 'aboutListTileTitle',
    );
    expect(
      wrapped.licensesPageTitle,
      base.licensesPageTitle,
      reason: 'licensesPageTitle',
    );
    expect(
      wrapped.licensesPackageDetailText(3),
      base.licensesPackageDetailText(3),
      reason: 'licensesPackageDetailText',
    );
    expect(
      wrapped.pageRowsInfoTitle(3, 3, 3, false),
      base.pageRowsInfoTitle(3, 3, 3, false),
      reason: 'pageRowsInfoTitle',
    );
    expect(
      wrapped.rowsPerPageTitle,
      base.rowsPerPageTitle,
      reason: 'rowsPerPageTitle',
    );
    expect(
      wrapped.tabLabel(tabIndex: 3, tabCount: 3),
      base.tabLabel(tabIndex: 3, tabCount: 3),
      reason: 'tabLabel',
    );
    expect(
      wrapped.selectedRowCountTitle(3),
      base.selectedRowCountTitle(3),
      reason: 'selectedRowCountTitle',
    );
    expect(
      wrapped.cancelButtonLabel,
      base.cancelButtonLabel,
      reason: 'cancelButtonLabel',
    );
    expect(
      wrapped.closeButtonLabel,
      base.closeButtonLabel,
      reason: 'closeButtonLabel',
    );
    expect(
      wrapped.continueButtonLabel,
      base.continueButtonLabel,
      reason: 'continueButtonLabel',
    );
    expect(
      wrapped.copyButtonLabel,
      base.copyButtonLabel,
      reason: 'copyButtonLabel',
    );
    expect(
      wrapped.cutButtonLabel,
      base.cutButtonLabel,
      reason: 'cutButtonLabel',
    );
    expect(
      wrapped.scanTextButtonLabel,
      base.scanTextButtonLabel,
      reason: 'scanTextButtonLabel',
    );
    expect(wrapped.okButtonLabel, base.okButtonLabel, reason: 'okButtonLabel');
    expect(
      wrapped.pasteButtonLabel,
      base.pasteButtonLabel,
      reason: 'pasteButtonLabel',
    );
    expect(
      wrapped.selectAllButtonLabel,
      base.selectAllButtonLabel,
      reason: 'selectAllButtonLabel',
    );
    expect(
      wrapped.lookUpButtonLabel,
      base.lookUpButtonLabel,
      reason: 'lookUpButtonLabel',
    );
    expect(
      wrapped.searchWebButtonLabel,
      base.searchWebButtonLabel,
      reason: 'searchWebButtonLabel',
    );
    expect(
      wrapped.shareButtonLabel,
      base.shareButtonLabel,
      reason: 'shareButtonLabel',
    );
    expect(
      wrapped.viewLicensesButtonLabel,
      base.viewLicensesButtonLabel,
      reason: 'viewLicensesButtonLabel',
    );
    expect(
      wrapped.anteMeridiemAbbreviation,
      base.anteMeridiemAbbreviation,
      reason: 'anteMeridiemAbbreviation',
    );
    expect(
      wrapped.postMeridiemAbbreviation,
      base.postMeridiemAbbreviation,
      reason: 'postMeridiemAbbreviation',
    );
    expect(
      wrapped.timePickerHourModeAnnouncement,
      base.timePickerHourModeAnnouncement,
      reason: 'timePickerHourModeAnnouncement',
    );
    expect(
      wrapped.timePickerMinuteModeAnnouncement,
      base.timePickerMinuteModeAnnouncement,
      reason: 'timePickerMinuteModeAnnouncement',
    );
    expect(
      wrapped.modalBarrierDismissLabel,
      base.modalBarrierDismissLabel,
      reason: 'modalBarrierDismissLabel',
    );
    expect(
      wrapped.menuDismissLabel,
      base.menuDismissLabel,
      reason: 'menuDismissLabel',
    );
    expect(wrapped.drawerLabel, base.drawerLabel, reason: 'drawerLabel');
    expect(
      wrapped.popupMenuLabel,
      base.popupMenuLabel,
      reason: 'popupMenuLabel',
    );
    expect(
      wrapped.menuBarMenuLabel,
      base.menuBarMenuLabel,
      reason: 'menuBarMenuLabel',
    );
    expect(wrapped.dialogLabel, base.dialogLabel, reason: 'dialogLabel');
    expect(
      wrapped.alertDialogLabel,
      base.alertDialogLabel,
      reason: 'alertDialogLabel',
    );
    expect(
      wrapped.searchFieldLabel,
      base.searchFieldLabel,
      reason: 'searchFieldLabel',
    );
    expect(
      wrapped.currentDateLabel,
      base.currentDateLabel,
      reason: 'currentDateLabel',
    );
    expect(
      wrapped.selectedDateLabel,
      base.selectedDateLabel,
      reason: 'selectedDateLabel',
    );
    expect(wrapped.scrimLabel, base.scrimLabel, reason: 'scrimLabel');
    expect(
      wrapped.bottomSheetLabel,
      base.bottomSheetLabel,
      reason: 'bottomSheetLabel',
    );
    expect(
      wrapped.scrimOnTapHint('Submersion'),
      base.scrimOnTapHint('Submersion'),
      reason: 'scrimOnTapHint',
    );
    expect(
      wrapped.timeOfDayFormat(alwaysUse24HourFormat: false),
      base.timeOfDayFormat(alwaysUse24HourFormat: false),
      reason: 'timeOfDayFormat',
    );
    expect(
      wrapped.scriptCategory,
      base.scriptCategory,
      reason: 'scriptCategory',
    );
    expect(
      wrapped.formatDecimal(3),
      base.formatDecimal(3),
      reason: 'formatDecimal',
    );
    expect(
      wrapped.formatHour(
        const TimeOfDay(hour: 9, minute: 5),
        alwaysUse24HourFormat: false,
      ),
      base.formatHour(
        const TimeOfDay(hour: 9, minute: 5),
        alwaysUse24HourFormat: false,
      ),
      reason: 'formatHour',
    );
    expect(
      wrapped.formatMinute(const TimeOfDay(hour: 9, minute: 5)),
      base.formatMinute(const TimeOfDay(hour: 9, minute: 5)),
      reason: 'formatMinute',
    );
    expect(
      wrapped.formatTimeOfDay(
        const TimeOfDay(hour: 9, minute: 5),
        alwaysUse24HourFormat: false,
      ),
      base.formatTimeOfDay(
        const TimeOfDay(hour: 9, minute: 5),
        alwaysUse24HourFormat: false,
      ),
      reason: 'formatTimeOfDay',
    );
    expect(
      wrapped.formatYear(date),
      base.formatYear(date),
      reason: 'formatYear',
    );
    expect(
      wrapped.formatCompactDate(date),
      base.formatCompactDate(date),
      reason: 'formatCompactDate',
    );
    expect(
      wrapped.formatShortDate(date),
      base.formatShortDate(date),
      reason: 'formatShortDate',
    );
    expect(
      wrapped.formatMediumDate(date),
      base.formatMediumDate(date),
      reason: 'formatMediumDate',
    );
    expect(
      wrapped.formatFullDate(date),
      base.formatFullDate(date),
      reason: 'formatFullDate',
    );
    expect(
      wrapped.formatMonthYear(date),
      base.formatMonthYear(date),
      reason: 'formatMonthYear',
    );
    expect(
      wrapped.formatShortMonthDay(date),
      base.formatShortMonthDay(date),
      reason: 'formatShortMonthDay',
    );
    expect(
      wrapped.parseCompactDate('11/06/2026'),
      base.parseCompactDate('11/06/2026'),
      reason: 'parseCompactDate',
    );
    expect(
      wrapped.narrowWeekdays,
      base.narrowWeekdays,
      reason: 'narrowWeekdays',
    );
    expect(wrapped.dateSeparator, base.dateSeparator, reason: 'dateSeparator');
    expect(wrapped.dateHelpText, base.dateHelpText, reason: 'dateHelpText');
    expect(
      wrapped.selectYearSemanticsLabel,
      base.selectYearSemanticsLabel,
      reason: 'selectYearSemanticsLabel',
    );
    expect(
      wrapped.unspecifiedDate,
      base.unspecifiedDate,
      reason: 'unspecifiedDate',
    );
    expect(
      wrapped.unspecifiedDateRange,
      base.unspecifiedDateRange,
      reason: 'unspecifiedDateRange',
    );
    expect(
      wrapped.dateInputLabel,
      base.dateInputLabel,
      reason: 'dateInputLabel',
    );
    expect(
      wrapped.dateRangeStartLabel,
      base.dateRangeStartLabel,
      reason: 'dateRangeStartLabel',
    );
    expect(
      wrapped.dateRangeEndLabel,
      base.dateRangeEndLabel,
      reason: 'dateRangeEndLabel',
    );
    expect(
      wrapped.dateRangeStartDateSemanticLabel('Submersion'),
      base.dateRangeStartDateSemanticLabel('Submersion'),
      reason: 'dateRangeStartDateSemanticLabel',
    );
    expect(
      wrapped.dateRangeEndDateSemanticLabel('Submersion'),
      base.dateRangeEndDateSemanticLabel('Submersion'),
      reason: 'dateRangeEndDateSemanticLabel',
    );
    expect(
      wrapped.invalidDateFormatLabel,
      base.invalidDateFormatLabel,
      reason: 'invalidDateFormatLabel',
    );
    expect(
      wrapped.invalidDateRangeLabel,
      base.invalidDateRangeLabel,
      reason: 'invalidDateRangeLabel',
    );
    expect(
      wrapped.dateOutOfRangeLabel,
      base.dateOutOfRangeLabel,
      reason: 'dateOutOfRangeLabel',
    );
    expect(
      wrapped.saveButtonLabel,
      base.saveButtonLabel,
      reason: 'saveButtonLabel',
    );
    expect(
      wrapped.datePickerHelpText,
      base.datePickerHelpText,
      reason: 'datePickerHelpText',
    );
    expect(
      wrapped.dateRangePickerHelpText,
      base.dateRangePickerHelpText,
      reason: 'dateRangePickerHelpText',
    );
    expect(
      wrapped.calendarModeButtonLabel,
      base.calendarModeButtonLabel,
      reason: 'calendarModeButtonLabel',
    );
    expect(
      wrapped.inputDateModeButtonLabel,
      base.inputDateModeButtonLabel,
      reason: 'inputDateModeButtonLabel',
    );
    expect(
      wrapped.timePickerDialHelpText,
      base.timePickerDialHelpText,
      reason: 'timePickerDialHelpText',
    );
    expect(
      wrapped.timePickerInputHelpText,
      base.timePickerInputHelpText,
      reason: 'timePickerInputHelpText',
    );
    expect(
      wrapped.timePickerHourLabel,
      base.timePickerHourLabel,
      reason: 'timePickerHourLabel',
    );
    expect(
      wrapped.timePickerMinuteLabel,
      base.timePickerMinuteLabel,
      reason: 'timePickerMinuteLabel',
    );
    expect(
      wrapped.invalidTimeLabel,
      base.invalidTimeLabel,
      reason: 'invalidTimeLabel',
    );
    expect(
      wrapped.dialModeButtonLabel,
      base.dialModeButtonLabel,
      reason: 'dialModeButtonLabel',
    );
    expect(
      wrapped.inputTimeModeButtonLabel,
      base.inputTimeModeButtonLabel,
      reason: 'inputTimeModeButtonLabel',
    );
    expect(wrapped.signedInLabel, base.signedInLabel, reason: 'signedInLabel');
    expect(
      wrapped.hideAccountsLabel,
      base.hideAccountsLabel,
      reason: 'hideAccountsLabel',
    );
    expect(
      wrapped.showAccountsLabel,
      base.showAccountsLabel,
      reason: 'showAccountsLabel',
    );
    expect(
      wrapped.reorderItemToStart,
      base.reorderItemToStart,
      reason: 'reorderItemToStart',
    );
    expect(
      wrapped.reorderItemToEnd,
      base.reorderItemToEnd,
      reason: 'reorderItemToEnd',
    );
    expect(wrapped.reorderItemUp, base.reorderItemUp, reason: 'reorderItemUp');
    expect(
      wrapped.reorderItemDown,
      base.reorderItemDown,
      reason: 'reorderItemDown',
    );
    expect(
      wrapped.reorderItemLeft,
      base.reorderItemLeft,
      reason: 'reorderItemLeft',
    );
    expect(
      wrapped.reorderItemRight,
      base.reorderItemRight,
      reason: 'reorderItemRight',
    );
    expect(
      wrapped.expandedIconTapHint,
      base.expandedIconTapHint,
      reason: 'expandedIconTapHint',
    );
    expect(
      wrapped.collapsedIconTapHint,
      base.collapsedIconTapHint,
      reason: 'collapsedIconTapHint',
    );
    expect(
      wrapped.expansionTileExpandedHint,
      base.expansionTileExpandedHint,
      reason: 'expansionTileExpandedHint',
    );
    expect(
      wrapped.expansionTileCollapsedHint,
      base.expansionTileCollapsedHint,
      reason: 'expansionTileCollapsedHint',
    );
    expect(
      wrapped.expansionTileExpandedTapHint,
      base.expansionTileExpandedTapHint,
      reason: 'expansionTileExpandedTapHint',
    );
    expect(
      wrapped.expansionTileCollapsedTapHint,
      base.expansionTileCollapsedTapHint,
      reason: 'expansionTileCollapsedTapHint',
    );
    expect(wrapped.expandedHint, base.expandedHint, reason: 'expandedHint');
    expect(wrapped.collapsedHint, base.collapsedHint, reason: 'collapsedHint');
    expect(
      wrapped.remainingTextFieldCharacterCount(3),
      base.remainingTextFieldCharacterCount(3),
      reason: 'remainingTextFieldCharacterCount',
    );
    expect(
      wrapped.refreshIndicatorSemanticLabel,
      base.refreshIndicatorSemanticLabel,
      reason: 'refreshIndicatorSemanticLabel',
    );
    expect(
      wrapped.keyboardKeyAlt,
      base.keyboardKeyAlt,
      reason: 'keyboardKeyAlt',
    );
    expect(
      wrapped.keyboardKeyAltGraph,
      base.keyboardKeyAltGraph,
      reason: 'keyboardKeyAltGraph',
    );
    expect(
      wrapped.keyboardKeyBackspace,
      base.keyboardKeyBackspace,
      reason: 'keyboardKeyBackspace',
    );
    expect(
      wrapped.keyboardKeyCapsLock,
      base.keyboardKeyCapsLock,
      reason: 'keyboardKeyCapsLock',
    );
    expect(
      wrapped.keyboardKeyChannelDown,
      base.keyboardKeyChannelDown,
      reason: 'keyboardKeyChannelDown',
    );
    expect(
      wrapped.keyboardKeyChannelUp,
      base.keyboardKeyChannelUp,
      reason: 'keyboardKeyChannelUp',
    );
    expect(
      wrapped.keyboardKeyControl,
      base.keyboardKeyControl,
      reason: 'keyboardKeyControl',
    );
    expect(
      wrapped.keyboardKeyDelete,
      base.keyboardKeyDelete,
      reason: 'keyboardKeyDelete',
    );
    expect(
      wrapped.keyboardKeyEject,
      base.keyboardKeyEject,
      reason: 'keyboardKeyEject',
    );
    expect(
      wrapped.keyboardKeyEnd,
      base.keyboardKeyEnd,
      reason: 'keyboardKeyEnd',
    );
    expect(
      wrapped.keyboardKeyEscape,
      base.keyboardKeyEscape,
      reason: 'keyboardKeyEscape',
    );
    expect(wrapped.keyboardKeyFn, base.keyboardKeyFn, reason: 'keyboardKeyFn');
    expect(
      wrapped.keyboardKeyHome,
      base.keyboardKeyHome,
      reason: 'keyboardKeyHome',
    );
    expect(
      wrapped.keyboardKeyInsert,
      base.keyboardKeyInsert,
      reason: 'keyboardKeyInsert',
    );
    expect(
      wrapped.keyboardKeyMeta,
      base.keyboardKeyMeta,
      reason: 'keyboardKeyMeta',
    );
    expect(
      wrapped.keyboardKeyMetaMacOs,
      base.keyboardKeyMetaMacOs,
      reason: 'keyboardKeyMetaMacOs',
    );
    expect(
      wrapped.keyboardKeyMetaWindows,
      base.keyboardKeyMetaWindows,
      reason: 'keyboardKeyMetaWindows',
    );
    expect(
      wrapped.keyboardKeyNumLock,
      base.keyboardKeyNumLock,
      reason: 'keyboardKeyNumLock',
    );
    expect(
      wrapped.keyboardKeyNumpad1,
      base.keyboardKeyNumpad1,
      reason: 'keyboardKeyNumpad1',
    );
    expect(
      wrapped.keyboardKeyNumpad2,
      base.keyboardKeyNumpad2,
      reason: 'keyboardKeyNumpad2',
    );
    expect(
      wrapped.keyboardKeyNumpad3,
      base.keyboardKeyNumpad3,
      reason: 'keyboardKeyNumpad3',
    );
    expect(
      wrapped.keyboardKeyNumpad4,
      base.keyboardKeyNumpad4,
      reason: 'keyboardKeyNumpad4',
    );
    expect(
      wrapped.keyboardKeyNumpad5,
      base.keyboardKeyNumpad5,
      reason: 'keyboardKeyNumpad5',
    );
    expect(
      wrapped.keyboardKeyNumpad6,
      base.keyboardKeyNumpad6,
      reason: 'keyboardKeyNumpad6',
    );
    expect(
      wrapped.keyboardKeyNumpad7,
      base.keyboardKeyNumpad7,
      reason: 'keyboardKeyNumpad7',
    );
    expect(
      wrapped.keyboardKeyNumpad8,
      base.keyboardKeyNumpad8,
      reason: 'keyboardKeyNumpad8',
    );
    expect(
      wrapped.keyboardKeyNumpad9,
      base.keyboardKeyNumpad9,
      reason: 'keyboardKeyNumpad9',
    );
    expect(
      wrapped.keyboardKeyNumpad0,
      base.keyboardKeyNumpad0,
      reason: 'keyboardKeyNumpad0',
    );
    expect(
      wrapped.keyboardKeyNumpadAdd,
      base.keyboardKeyNumpadAdd,
      reason: 'keyboardKeyNumpadAdd',
    );
    expect(
      wrapped.keyboardKeyNumpadComma,
      base.keyboardKeyNumpadComma,
      reason: 'keyboardKeyNumpadComma',
    );
    expect(
      wrapped.keyboardKeyNumpadDecimal,
      base.keyboardKeyNumpadDecimal,
      reason: 'keyboardKeyNumpadDecimal',
    );
    expect(
      wrapped.keyboardKeyNumpadDivide,
      base.keyboardKeyNumpadDivide,
      reason: 'keyboardKeyNumpadDivide',
    );
    expect(
      wrapped.keyboardKeyNumpadEnter,
      base.keyboardKeyNumpadEnter,
      reason: 'keyboardKeyNumpadEnter',
    );
    expect(
      wrapped.keyboardKeyNumpadEqual,
      base.keyboardKeyNumpadEqual,
      reason: 'keyboardKeyNumpadEqual',
    );
    expect(
      wrapped.keyboardKeyNumpadMultiply,
      base.keyboardKeyNumpadMultiply,
      reason: 'keyboardKeyNumpadMultiply',
    );
    expect(
      wrapped.keyboardKeyNumpadParenLeft,
      base.keyboardKeyNumpadParenLeft,
      reason: 'keyboardKeyNumpadParenLeft',
    );
    expect(
      wrapped.keyboardKeyNumpadParenRight,
      base.keyboardKeyNumpadParenRight,
      reason: 'keyboardKeyNumpadParenRight',
    );
    expect(
      wrapped.keyboardKeyNumpadSubtract,
      base.keyboardKeyNumpadSubtract,
      reason: 'keyboardKeyNumpadSubtract',
    );
    expect(
      wrapped.keyboardKeyPageDown,
      base.keyboardKeyPageDown,
      reason: 'keyboardKeyPageDown',
    );
    expect(
      wrapped.keyboardKeyPageUp,
      base.keyboardKeyPageUp,
      reason: 'keyboardKeyPageUp',
    );
    expect(
      wrapped.keyboardKeyPower,
      base.keyboardKeyPower,
      reason: 'keyboardKeyPower',
    );
    expect(
      wrapped.keyboardKeyPowerOff,
      base.keyboardKeyPowerOff,
      reason: 'keyboardKeyPowerOff',
    );
    expect(
      wrapped.keyboardKeyPrintScreen,
      base.keyboardKeyPrintScreen,
      reason: 'keyboardKeyPrintScreen',
    );
    expect(
      wrapped.keyboardKeyScrollLock,
      base.keyboardKeyScrollLock,
      reason: 'keyboardKeyScrollLock',
    );
    expect(
      wrapped.keyboardKeySelect,
      base.keyboardKeySelect,
      reason: 'keyboardKeySelect',
    );
    expect(
      wrapped.keyboardKeyShift,
      base.keyboardKeyShift,
      reason: 'keyboardKeyShift',
    );
    expect(
      wrapped.keyboardKeySpace,
      base.keyboardKeySpace,
      reason: 'keyboardKeySpace',
    );
  });
}
