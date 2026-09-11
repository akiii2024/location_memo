import 'dart:convert';

import 'package:hive/hive.dart';

class CollaborationMetadata {
  final String ownerUid;
  final bool isOwner;
  final String? ownerEmail;
  final DateTime? registeredAt;
  final String? remoteMapId;
  final DateTime? lastSyncedAt;

  const CollaborationMetadata({
    required this.ownerUid,
    required this.isOwner,
    this.ownerEmail,
    this.registeredAt,
    this.remoteMapId,
    this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'isOwner': isOwner,
      if (ownerEmail != null) 'ownerEmail': ownerEmail,
      if (registeredAt != null) 'registeredAt': registeredAt!.toIso8601String(),
      if (remoteMapId != null) 'remoteMapId': remoteMapId,
      if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
    };
  }

  static CollaborationMetadata fromJson(Map<dynamic, dynamic> json) {
    final ownerUid = json['ownerUid']?.toString();
    if (ownerUid == null || ownerUid.isEmpty) {
      throw ArgumentError('ownerUid is required in collaboration metadata');
    }
    final registeredRaw = json['registeredAt'];
    DateTime? registeredAt;
    DateTime? lastSyncedAt;
    if (registeredRaw is String) {
      registeredAt = DateTime.tryParse(registeredRaw);
    }
    final lastSyncedRaw = json['lastSyncedAt'];
    if (lastSyncedRaw is String) {
      lastSyncedAt = DateTime.tryParse(lastSyncedRaw);
    }
    return CollaborationMetadata(
      ownerUid: ownerUid,
      isOwner: json['isOwner'] == true,
      ownerEmail: json['ownerEmail']?.toString(),
      registeredAt: registeredAt,
      remoteMapId: json['remoteMapId']?.toString(),
      lastSyncedAt: lastSyncedAt,
    );
  }
}

class CollaborationMetadataStore {
  CollaborationMetadataStore._();

  static final CollaborationMetadataStore instance =
      CollaborationMetadataStore._();

  static const _boxName = 'collaboration_metadata';

  Box<dynamic>? _box;

  Future<Box<dynamic>> _ensureBox() async {
    if (_box != null) {
      return _box!;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  String _keyForMap(int mapId) => 'map_$mapId';

  Future<void> saveForMap(int mapId, CollaborationMetadata metadata) async {
    final box = await _ensureBox();
    await box.put(_keyForMap(mapId), metadata.toJson());
  }

  Future<CollaborationMetadata?> getForMap(int mapId) async {
    final box = await _ensureBox();
    final raw = box.get(_keyForMap(mapId));
    if (raw is Map) {
      return CollaborationMetadata.fromJson(raw);
    }
    if (raw is Map<dynamic, dynamic>) {
      return CollaborationMetadata.fromJson(raw);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return CollaborationMetadata.fromJson(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Returns the local map associated with a remote map. Older metadata only
  /// stored the owner UID, so a numeric remote document id is also matched to
  /// the metadata key during the additive migration period.
  Future<int?> findLocalMapId({
    required String ownerUid,
    required String remoteMapId,
  }) async {
    final box = await _ensureBox();
    for (final entry in box.toMap().entries) {
      final raw = entry.value;
      CollaborationMetadata? metadata;
      try {
        if (raw is Map) {
          metadata = CollaborationMetadata.fromJson(raw);
        } else if (raw is String) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            metadata = CollaborationMetadata.fromJson(decoded);
          }
        }
      } catch (_) {
        continue;
      }
      if (metadata == null || metadata.ownerUid != ownerUid) continue;

      final keyMatch = RegExp(r'^map_(\d+)$').firstMatch(entry.key.toString());
      final localMapId = int.tryParse(keyMatch?.group(1) ?? '');
      if (localMapId == null) continue;
      if (metadata.remoteMapId == remoteMapId ||
          (metadata.remoteMapId == null &&
              remoteMapId == localMapId.toString())) {
        return localMapId;
      }
    }
    return null;
  }

  Future<void> deleteForMap(int mapId) async {
    final box = await _ensureBox();
    await box.delete(_keyForMap(mapId));
  }

  Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }
}
