/// Where the diver's tissues stand after the last dive, as one
/// classification shared by every surface readout (issue #4228): the
/// "active load" gate of the current dive load page and its "no residual
/// tissue load" note both read it, so they can never disagree.
enum TissueLoadState {
  /// At least one compartment still holds inert gas meaningfully above the
  /// surface level.
  loaded,

  /// Nothing is meaningfully above the surface level any more, but some
  /// gas is still moving: a slow compartment's last few millibar leaving,
  /// fast compartments refilling with nitrogen after oxygen deco, or helium
  /// still on its way out.
  settling,

  /// Every compartment holds both gases at the inspired pressure.
  settled,
}
