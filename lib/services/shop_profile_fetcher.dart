import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'media_prefetch_service.dart';

class ShopProfileFetchResult {
	const ShopProfileFetchResult({
		required this.collection,
		required this.doc,
		required this.data,
	});

	final String collection;
	final DocumentSnapshot<Map<String, dynamic>> doc;
	final Map<String, dynamic> data;
}

class ShopProfileFetcher {
	ShopProfileFetcher._();

	static const List<String> _collections = <String>[
		'market_registrations',
		'shop_registrations',
		'restaurant_registrations',
		'pharmacy_registrations',
		'other_registrations',
	];

	static Future<ShopProfileFetchResult?> findByUser(
		String userId, {
		String? email,
	}) async {
		if (userId.isEmpty) return null;

		for (final String collection in _collections) {
      debugPrint('[DEBUG] ShopProfileFetcher: searching collection=$collection for userId=$userId');
			final ShopProfileFetchResult? result =
					await _findInCollection(collection, userId, email: email);
			if (result != null) {
        debugPrint('[DEBUG] ShopProfileFetcher: found user in collection=$collection, docId=${result.doc.id}, data=${result.data}');
				MediaPrefetchService.instance.prefetchImages(
					_extractMediaUrls(result.data).take(_prefetchLimit),
				);
				return result;
			}
		}
		return null;
	}

	static Future<ShopProfileFetchResult?> _findInCollection(
		String collection,
		String userId, {
		String? email,
	}) async {
		final CollectionReference<Map<String, dynamic>> ref =
				FirebaseFirestore.instance.collection(collection);

		final DocumentSnapshot<Map<String, dynamic>> directDoc = await ref.doc(userId).get();
		final Map<String, dynamic>? directData = directDoc.data();
		if (directDoc.exists && directData != null) {
			return ShopProfileFetchResult(collection: collection, doc: directDoc, data: directData);
		}

		final QuerySnapshot<Map<String, dynamic>> ownerQuery = await ref
				.where('ownerId', isEqualTo: userId)
				.limit(1)
				.get();
		if (ownerQuery.docs.isNotEmpty) {
			final QueryDocumentSnapshot<Map<String, dynamic>> doc = ownerQuery.docs.first;
			return ShopProfileFetchResult(collection: collection, doc: doc, data: doc.data());
		}

		if (email != null && email.isNotEmpty) {
			final QuerySnapshot<Map<String, dynamic>> emailQuery = await ref
					.where('email', isEqualTo: email)
					.limit(1)
					.get();
			if (emailQuery.docs.isNotEmpty) {
				final QueryDocumentSnapshot<Map<String, dynamic>> doc = emailQuery.docs.first;
				return ShopProfileFetchResult(collection: collection, doc: doc, data: doc.data());
			}
		}
		return null;
	}

	static const int _prefetchLimit = 12;

	static Iterable<String> _extractMediaUrls(Map<String, dynamic> data) sync* {
		Iterable<String> walk(dynamic value) sync* {
			if (value is String && value.startsWith('http')) {
				yield value;
				return;
			}
			if (value is Map) {
				for (final entry in value.entries) {
					yield* walk(entry.value);
				}
				return;
			}
			if (value is Iterable) {
				for (final element in value) {
					yield* walk(element);
				}
			}
		}

		yield* walk(data);
	}
}
