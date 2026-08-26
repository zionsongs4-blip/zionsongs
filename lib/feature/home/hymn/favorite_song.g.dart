// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_song.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFavoriteSongCollection on Isar {
  IsarCollection<FavoriteSong> get favoriteSongs => this.collection();
}

const FavoriteSongSchema = CollectionSchema(
  name: r'FavoriteSong',
  id: 3312980408913995094,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'hymnId': PropertySchema(
      id: 1,
      name: r'hymnId',
      type: IsarType.string,
    )
  },
  estimateSize: _favoriteSongEstimateSize,
  serialize: _favoriteSongSerialize,
  deserialize: _favoriteSongDeserialize,
  deserializeProp: _favoriteSongDeserializeProp,
  idName: r'id',
  indexes: {
    r'hymnId': IndexSchema(
      id: -3067022437716651328,
      name: r'hymnId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'hymnId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _favoriteSongGetId,
  getLinks: _favoriteSongGetLinks,
  attach: _favoriteSongAttach,
  version: '3.1.0+1',
);

int _favoriteSongEstimateSize(
  FavoriteSong object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.hymnId.length * 3;
  return bytesCount;
}

void _favoriteSongSerialize(
  FavoriteSong object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.hymnId);
}

FavoriteSong _favoriteSongDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FavoriteSong();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.hymnId = reader.readString(offsets[1]);
  object.id = id;
  return object;
}

P _favoriteSongDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _favoriteSongGetId(FavoriteSong object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _favoriteSongGetLinks(FavoriteSong object) {
  return [];
}

void _favoriteSongAttach(
    IsarCollection<dynamic> col, Id id, FavoriteSong object) {
  object.id = id;
}

extension FavoriteSongByIndex on IsarCollection<FavoriteSong> {
  Future<FavoriteSong?> getByHymnId(String hymnId) {
    return getByIndex(r'hymnId', [hymnId]);
  }

  FavoriteSong? getByHymnIdSync(String hymnId) {
    return getByIndexSync(r'hymnId', [hymnId]);
  }

  Future<bool> deleteByHymnId(String hymnId) {
    return deleteByIndex(r'hymnId', [hymnId]);
  }

  bool deleteByHymnIdSync(String hymnId) {
    return deleteByIndexSync(r'hymnId', [hymnId]);
  }

  Future<List<FavoriteSong?>> getAllByHymnId(List<String> hymnIdValues) {
    final values = hymnIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'hymnId', values);
  }

  List<FavoriteSong?> getAllByHymnIdSync(List<String> hymnIdValues) {
    final values = hymnIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'hymnId', values);
  }

  Future<int> deleteAllByHymnId(List<String> hymnIdValues) {
    final values = hymnIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'hymnId', values);
  }

  int deleteAllByHymnIdSync(List<String> hymnIdValues) {
    final values = hymnIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'hymnId', values);
  }

  Future<Id> putByHymnId(FavoriteSong object) {
    return putByIndex(r'hymnId', object);
  }

  Id putByHymnIdSync(FavoriteSong object, {bool saveLinks = true}) {
    return putByIndexSync(r'hymnId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByHymnId(List<FavoriteSong> objects) {
    return putAllByIndex(r'hymnId', objects);
  }

  List<Id> putAllByHymnIdSync(List<FavoriteSong> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'hymnId', objects, saveLinks: saveLinks);
  }
}

extension FavoriteSongQueryWhereSort
    on QueryBuilder<FavoriteSong, FavoriteSong, QWhere> {
  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FavoriteSongQueryWhere
    on QueryBuilder<FavoriteSong, FavoriteSong, QWhereClause> {
  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> hymnIdEqualTo(
      String hymnId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'hymnId',
        value: [hymnId],
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterWhereClause> hymnIdNotEqualTo(
      String hymnId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'hymnId',
              lower: [],
              upper: [hymnId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'hymnId',
              lower: [hymnId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'hymnId',
              lower: [hymnId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'hymnId',
              lower: [],
              upper: [hymnId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension FavoriteSongQueryFilter
    on QueryBuilder<FavoriteSong, FavoriteSong, QFilterCondition> {
  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> hymnIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> hymnIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hymnId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hymnId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> hymnIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'hymnId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hymnId',
        value: '',
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition>
      hymnIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'hymnId',
        value: '',
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension FavoriteSongQueryObject
    on QueryBuilder<FavoriteSong, FavoriteSong, QFilterCondition> {}

extension FavoriteSongQueryLinks
    on QueryBuilder<FavoriteSong, FavoriteSong, QFilterCondition> {}

extension FavoriteSongQuerySortBy
    on QueryBuilder<FavoriteSong, FavoriteSong, QSortBy> {
  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> sortByHymnId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hymnId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> sortByHymnIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hymnId', Sort.desc);
    });
  }
}

extension FavoriteSongQuerySortThenBy
    on QueryBuilder<FavoriteSong, FavoriteSong, QSortThenBy> {
  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenByHymnId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hymnId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenByHymnIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hymnId', Sort.desc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension FavoriteSongQueryWhereDistinct
    on QueryBuilder<FavoriteSong, FavoriteSong, QDistinct> {
  QueryBuilder<FavoriteSong, FavoriteSong, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<FavoriteSong, FavoriteSong, QDistinct> distinctByHymnId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hymnId', caseSensitive: caseSensitive);
    });
  }
}

extension FavoriteSongQueryProperty
    on QueryBuilder<FavoriteSong, FavoriteSong, QQueryProperty> {
  QueryBuilder<FavoriteSong, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FavoriteSong, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<FavoriteSong, String, QQueryOperations> hymnIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hymnId');
    });
  }
}
