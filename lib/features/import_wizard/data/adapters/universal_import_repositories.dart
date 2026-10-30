part of 'universal_adapter.dart';

/// The repositories a UDDF import writes through. Every optional one is
/// supplied here: the importer skips the entities a missing one owns, so
/// leaving one out drops that data from real imports without a word.
ImportRepositories universalImportRepositories(ProviderContainer container) {
  return ImportRepositories(
    tripRepository: container.read(tripRepositoryProvider),
    equipmentRepository: container.read(equipmentRepositoryProvider),
    equipmentSetRepository: container.read(equipmentSetRepositoryProvider),
    buddyRepository: container.read(buddyRepositoryProvider),
    diveCenterRepository: container.read(diveCenterRepositoryProvider),
    certificationRepository: container.read(certificationRepositoryProvider),
    tagRepository: container.read(tagRepositoryProvider),
    diveTypeRepository: container.read(diveTypeRepositoryProvider),
    diveRoleRepository: container.read(diveRoleRepositoryProvider),
    siteRepository: container.read(siteRepositoryProvider),
    diveRepository: container.read(diveRepositoryProvider),
    tankPressureRepository: container.read(tankPressureRepositoryProvider),
    speciesRepository: container.read(speciesRepositoryProvider),
    courseRepository: container.read(courseRepositoryProvider),
    serviceRecordRepository: container.read(serviceRecordRepositoryProvider),
    diveComputerRepository: container.read(diveComputerRepositoryProvider),
    diveComputerConnectionRepository: container.read(
      diveComputerConnectionRepositoryProvider,
    ),
    // Without it every check-in in the file is skipped (condition phase
    // 3a); the field is optional only for legacy callers.
    equipmentObservationRepository: container.read(
      equipmentObservationRepositoryProvider,
    ),
    // Site types and site tags (issue #1765); without them an import
    // restores sites but not their classification.
    siteTypeRepository: container.read(siteTypeRepositoryProvider),
    siteClassificationRepository: container.read(
      siteClassificationRepositoryProvider,
    ),
    // Equipment tags (issue #1942); without it imported gear arrives with
    // none of its tags.
    equipmentTagRepository: container.read(equipmentTagRepositoryProvider),
    // Equipment locations (v268); without both, a CSV's Location column is
    // dropped.
    equipmentLocationRepository: container.read(
      equipmentLocationRepositoryProvider,
    ),
    equipmentLocationMoveRepository: container.read(
      equipmentLocationMoveRepositoryProvider,
    ),
    // Site features (issue #2200); without it every feature in the file is
    // dropped and the site arrives with none of its markers.
    siteFeatureRepository: container.read(siteFeatureRepositoryProvider),
    // Cylinder fills (passports phase 5); without both, every fill in a
    // fills CSV is skipped.
    cylinderFillRepository: container.read(cylinderFillRepositoryProvider),
    cylinderPassportRepository: container.read(
      cylinderPassportRepositoryProvider,
    ),
    // Service kinds and clocks (issue #2651); without them a backup's
    // custom kinds and clocks are skipped and record kinds stay unset.
    serviceKindRepository: container.read(serviceKindRepositoryProvider),
    serviceScheduleRepository: container.read(
      serviceScheduleRepositoryProvider,
    ),
    // Certification currency (issue #2267); without it a backup's custom
    // rules, prefs and refresher history are skipped.
    certificationCurrencyRepository: container.read(
      certificationCurrencyRepositoryProvider,
    ),
  );
}
