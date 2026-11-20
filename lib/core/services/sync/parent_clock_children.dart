/// Tables whose rows have no sync clock of their own and ride on their
/// parent's: an incremental export selects the parent by its clock, then
/// all of its rows of the table. Marking such a row pending reaches no
/// other device unless its parent is marked pending too.
///
/// The parent is the row's change log parent (`changeLogParents`).
const Set<String> syncRidesParentClockTables = {'equipment_findings'};
