import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';

/// What a scanned, pasted or opened tag string turns out to be (gear tag
/// spec 8.2), for either kind of tag.
sealed class TagResolution {
  const TagResolution();
}

/// A tag for an item the diver can see. [type] is what the item is now,
/// which picks the page; [link] is what the tag said.
class OwnTaggedItem extends TagResolution {
  const OwnTaggedItem({
    required this.equipmentId,
    required this.type,
    required this.link,
  });

  final String equipmentId;
  final EquipmentType type;
  final TagLinkDecoded link;
}

/// A cylinder tag no item the diver can see holds.
class ForeignCylinderTag extends TagResolution {
  const ForeignCylinderTag(this.tag, {this.newerFormat = false});

  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// A gear tag no item the diver can see holds.
class ForeignGearTag extends TagResolution {
  const ForeignGearTag(this.tag, {this.newerFormat = false});

  final GearTagPayload tag;
  final bool newerFormat;
}

/// Text that is no tag.
class UnreadableTag extends TagResolution {
  const UnreadableTag();
}

/// Decodes any tag string and looks its passport id up among the diver's
/// items of every type. The lookup is injected so the domain stays free of
/// the database.
class TagResolver {
  const TagResolver({required this.findHolder});

  final Future<PassportHolder?> Function(String passportId) findHolder;

  Future<TagResolution> resolve(String text) async {
    final link = TagLinkCodec.decode(text);
    if (link is! TagLinkDecoded) return const UnreadableTag();
    final holder = await findHolder(link.passportId);
    if (holder != null) {
      return OwnTaggedItem(
        equipmentId: holder.equipmentId,
        type: holder.type,
        link: link,
      );
    }
    return switch (link) {
      CylinderTagLink(:final payload, :final newerFormat) => ForeignCylinderTag(
        payload,
        newerFormat: newerFormat,
      ),
      GearTagLink(:final payload, :final newerFormat) => ForeignGearTag(
        payload,
        newerFormat: newerFormat,
      ),
    };
  }
}
