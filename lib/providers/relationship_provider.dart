import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/relationship_service.dart';

final relationshipServiceProvider = Provider<RelationshipService>((ref) => RelationshipService());
