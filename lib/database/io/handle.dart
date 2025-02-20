import 'dart:math';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dice_bear/dice_bear.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Condition;
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:tuple/tuple.dart';

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
  String uniqueAddressAndService;
  String address;
  String? formattedAddress;
  String service;
  String? country;
  String? defaultEmail;
  String? defaultPhone;
  @Transient()
  final String fakeName = "${faker.person.firstName()} ${faker.person.lastName()}";

  final RxnString _color = RxnString();
  String? get color => _color.value;
  set color(String? val) => _color.value = val;

  final contactRelation = ToOne<Contact>();
  @Transient()
  Contact? webContact;

  @Transient()
  Widget? _fakeAvatar;

  @Transient()
  Widget get fakeAvatar {
    if (_fakeAvatar != null) return _fakeAvatar!;
    Avatar _avatar = DiceBearBuilder(seed: address).build();
    _fakeAvatar = _avatar.toImage();
    return _fakeAvatar!;
  }

  Contact? get contact => kIsWeb ? webContact : contactRelation.target;
  String get displayName {
    if (ss.settings.redactedMode.value) {
      if (ss.settings.generateFakeContactNames.value) {
        return fakeName;
      } else if (ss.settings.hideContactInfo.value) {
        return "";
      }
    }
    if (address.startsWith("urn:biz")) return "Business";
    if (contact != null) return contact!.displayName;
    return address.contains("@") ? address : (formattedAddress ?? address);
  }
  String? get initials {
    // Remove any numbers, certain symbols, and non-alphabet characters
    if (address.startsWith("urn:biz")) return null;
    String importantChars = displayName.toUpperCase().replaceAll(RegExp(r'[^a-zA-Z _-]'), "").trim();
    if (importantChars.isEmpty) return null;

    // Split by a space or special character delimiter, take each of the items and
    // reduce it to just the capitalized first letter. Then join the array by an empty char
    List<String> initials = importantChars
        .split(RegExp(r'[ \-_]'))
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .toList();

    initials.removeRange(1, max(initials.length - 1, 1));

    return initials.join("").isEmpty ? null : initials.join("");
  }

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.formattedAddress,
    this.service = 'iMessage',
    this.uniqueAddressAndService = "",
    this.country,
    String? handleColor,
    this.defaultEmail,
    this.defaultPhone,
  }) {
    if (service.isEmpty) {
      service = 'iMessage';
    }
    if (uniqueAddressAndService.isEmpty) {
      uniqueAddressAndService = "$address/$service";
    }
    color = handleColor;
  }

  factory Handle.fromMap(Map<String, dynamic> json) => Handle(
    id: json["ROWID"] ?? json["id"],
    originalROWID: json["originalROWID"],
    address: json["address"],
    formattedAddress: json["formattedAddress"],
    service: json["service"] ?? "iMessage",
    uniqueAddressAndService: json["uniqueAddrAndService"] ?? "${json["address"]}/${json["service"] ?? "iMessage"}",
    country: json["country"],
    handleColor: json["color"],
    defaultPhone: json["defaultPhone"],
    defaultEmail: json["defaultEmail"],
  );

  /// Save a single handle - prefer [bulkSave] for multiple handles rather
  /// than iterating through them
  Handle save({bool updateColor = false, matchOnOriginalROWID = false}) {
    if (kIsWeb) return this;
    Database.runInTransaction(TxMode.write, () {
      Handle? existing;
      if (matchOnOriginalROWID) {
        existing = Handle.findOne(originalROWID: originalROWID);
      } else {
        existing = Handle.findOne(addressAndService: Tuple2(address, service));
      }

      if (existing != null) {
        id = existing.id;
        contactRelation.target = existing.contactRelation.target;
      } else if (existing == null && contactRelation.target == null) {
        contactRelation.target = cs.matchHandleToContact(this);
      }
      if (!updateColor) {
        color = existing?.color ?? color;
      }
      try {
        id = Database.handles.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save a list of handles
  static List<Handle> bulkSave(List<Handle> handles, {matchOnOriginalROWID = false}) {
    Database.runInTransaction(TxMode.write, () {
      /// Match existing to the handles to save, where possible
      for (Handle h in handles) {
        Handle? existing;
        if (matchOnOriginalROWID) {
          existing = Handle.findOne(originalROWID: h.originalROWID);
        } else {
          existing = Handle.findOne(addressAndService: Tuple2(h.address, h.service));
        }

        if (existing != null) {
          h.id = existing.id;
        } else {
          h.contactRelation.target ??= cs.matchHandleToContact(h);
        }
      }

      List<int> insertedIds = Database.handles.putMany(handles);
      for (int i = 0; i < insertedIds.length; i++) {
        handles[i].id = insertedIds[i];
      }
    });

    return handles;
  }

  Handle updateColor(String? newColor) {
    color = newColor;
    save();
    return this;
  }

  Handle updateDefaultPhone(String newPhone) {
    defaultPhone = newPhone;
    save();
    return this;
  }

  Handle updateDefaultEmail(String newEmail) {
    defaultEmail = newEmail;
    save();
    return this;
  }

  static Handle? findOne({int? id, int? originalROWID, Tuple2<String, String>? addressAndService}) {
    if (kIsWeb || id == 0) return null;
    if (id != null) {
      final handle = Database.handles.get(id) ?? Handle.findOne(originalROWID: id);
      return handle;
    } else if (originalROWID != null) {
      final query = Database.handles.query(Handle_.originalROWID.equals(originalROWID)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (addressAndService != null) {
      final query = Database.handles.query(Handle_.address.equals(addressAndService.item1) & Handle_.service.equals(addressAndService.item2)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static Handle merge(Handle handle1, Handle handle2) {
    handle1.id ??= handle2.id;
    handle1.originalROWID ??= handle2.originalROWID;
    handle1._color.value ??= handle2._color.value;
    handle1.country ??= handle2.country;
    handle1.formattedAddress ??= handle2.formattedAddress;
    if (isNullOrEmpty(handle1.defaultPhone)) {
      handle1.defaultPhone = handle2.defaultPhone;
    }
    if (isNullOrEmpty(handle1.defaultEmail)) {
      handle1.defaultEmail = handle2.defaultEmail;
    }

    return handle1;
  }

  /// Find a list of handles by the specified condition, or return all handles
  /// when no condition is specified
  static List<Handle> find({Condition<Handle>? cond}) {
    final query = Database.handles.query(cond).build();
    return query.find();
  }

  Map<String, dynamic> toMap({includeObjects = false}) {

    final output = {
      "ROWID": id,
      "originalROWID": originalROWID,
      "address": address,
      "formattedAddress": formattedAddress,
      "service": service,
      "uniqueAddrAndService": uniqueAddressAndService,
      "country": country,
      "color": color,
      "defaultPhone": defaultPhone,
      "defaultEmail": defaultEmail,
    };

    if (includeObjects) {
      output['contact'] = contact?.toMap();
      output['contactRelation'] = contactRelation.target?.toMap();
    }

    return output;
  }

  // Sometimes, the 'fakeName' handles are different on two handles that should be the same. (Even when redacted mode is off)
  // This method does a simple check on the Handle ids.
  bool isEqual(Handle? otherHandle) {
    if (otherHandle == null) return false;
    return id == otherHandle.id;
  }
}
