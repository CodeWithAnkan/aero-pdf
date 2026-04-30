// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_summary.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_members_api

extension GetAiSummaryCollection on Isar {
  IsarCollection<AiSummary> get aiSummarys => this.collection();
}

const AiSummarySchema = CollectionSchema(
  name: r'AiSummary',
  id: -3040754033448876100,
  properties: {
    r'bookId': PropertySchema(
      id: 0,
      name: r'bookId',
      type: IsarType.long,
    ),
    r'chunkSummariesJson': PropertySchema(
      id: 1,
      name: r'chunkSummariesJson',
      type: IsarType.string,
    ),
    r'globalSummary': PropertySchema(
      id: 2,
      name: r'globalSummary',
      type: IsarType.string,
    ),
    r'lastUpdated': PropertySchema(
      id: 3,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'quickSummary': PropertySchema(
      id: 4,
      name: r'quickSummary',
      type: IsarType.string,
    ),
    r'quickSummaryRange': PropertySchema(
      id: 5,
      name: r'quickSummaryRange',
      type: IsarType.string,
    )
  },
  estimateSize: _aiSummaryEstimateSize,
  serialize: _aiSummarySerialize,
  deserialize: _aiSummaryDeserialize,
  deserializeProp: _aiSummaryDeserializeProp,
  idName: r'id',
  indexes: {
    r'bookId': IndexSchema(
      id: 3567540928881766442,
      name: r'bookId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'bookId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _aiSummaryGetId,
  getLinks: _aiSummaryGetLinks,
  attach: _aiSummaryAttach,
  version: '3.1.0+1',
);

int _aiSummaryEstimateSize(
  AiSummary object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.chunkSummariesJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.globalSummary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.quickSummary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.quickSummaryRange;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _aiSummarySerialize(
  AiSummary object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bookId);
  writer.writeString(offsets[1], object.chunkSummariesJson);
  writer.writeString(offsets[2], object.globalSummary);
  writer.writeDateTime(offsets[3], object.lastUpdated);
  writer.writeString(offsets[4], object.quickSummary);
  writer.writeString(offsets[5], object.quickSummaryRange);
}

AiSummary _aiSummaryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AiSummary();
  object.bookId = reader.readLong(offsets[0]);
  object.chunkSummariesJson = reader.readStringOrNull(offsets[1]);
  object.globalSummary = reader.readStringOrNull(offsets[2]);
  object.id = id;
  object.lastUpdated = reader.readDateTimeOrNull(offsets[3]);
  object.quickSummary = reader.readStringOrNull(offsets[4]);
  object.quickSummaryRange = reader.readStringOrNull(offsets[5]);
  return object;
}

P _aiSummaryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _aiSummaryGetId(AiSummary object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _aiSummaryGetLinks(AiSummary object) {
  return [];
}

void _aiSummaryAttach(IsarCollection<dynamic> col, Id id, AiSummary object) {
  object.id = id;
}

extension AiSummaryByIndex on IsarCollection<AiSummary> {
  Future<AiSummary?> getByBookId(int bookId) {
    return getByIndex(r'bookId', [bookId]);
  }

  AiSummary? getByBookIdSync(int bookId) {
    return getByIndexSync(r'bookId', [bookId]);
  }

  Future<bool> deleteByBookId(int bookId) {
    return deleteByIndex(r'bookId', [bookId]);
  }

  bool deleteByBookIdSync(int bookId) {
    return deleteByIndexSync(r'bookId', [bookId]);
  }

  Future<List<AiSummary?>> getAllByBookId(List<int> bookIdValues) {
    final values = bookIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'bookId', values);
  }

  List<AiSummary?> getAllByBookIdSync(List<int> bookIdValues) {
    final values = bookIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'bookId', values);
  }

  Future<int> deleteAllByBookId(List<int> bookIdValues) {
    final values = bookIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'bookId', values);
  }

  int deleteAllByBookIdSync(List<int> bookIdValues) {
    final values = bookIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'bookId', values);
  }

  Future<Id> putByBookId(AiSummary object) {
    return putByIndex(r'bookId', object);
  }

  Id putByBookIdSync(AiSummary object, {bool saveLinks = true}) {
    return putByIndexSync(r'bookId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBookId(List<AiSummary> objects) {
    return putAllByIndex(r'bookId', objects);
  }

  List<Id> putAllByBookIdSync(List<AiSummary> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'bookId', objects, saveLinks: saveLinks);
  }
}

extension AiSummaryQueryWhereSort
    on QueryBuilder<AiSummary, AiSummary, QWhere> {
  QueryBuilder<AiSummary, AiSummary, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhere> anyBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bookId'),
      );
    });
  }
}

extension AiSummaryQueryWhere
    on QueryBuilder<AiSummary, AiSummary, QWhereClause> {
  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> idBetween(
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

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> bookIdEqualTo(
      int bookId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bookId',
        value: [bookId],
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> bookIdNotEqualTo(
      int bookId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bookId',
              lower: [],
              upper: [bookId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bookId',
              lower: [bookId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bookId',
              lower: [bookId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bookId',
              lower: [],
              upper: [bookId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> bookIdGreaterThan(
    int bookId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bookId',
        lower: [bookId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> bookIdLessThan(
    int bookId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bookId',
        lower: [],
        upper: [bookId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterWhereClause> bookIdBetween(
    int lowerBookId,
    int upperBookId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bookId',
        lower: [lowerBookId],
        includeLower: includeLower,
        upper: [upperBookId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AiSummaryQueryFilter
    on QueryBuilder<AiSummary, AiSummary, QFilterCondition> {
  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> bookIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bookId',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> bookIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bookId',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> bookIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bookId',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> bookIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bookId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'chunkSummariesJson',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'chunkSummariesJson',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkSummariesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chunkSummariesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chunkSummariesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkSummariesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      chunkSummariesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chunkSummariesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'globalSummary',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'globalSummary',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'globalSummary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'globalSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'globalSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'globalSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      globalSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'globalSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> idBetween(
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

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      lastUpdatedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUpdated',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      lastUpdatedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUpdated',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> lastUpdatedEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      lastUpdatedGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> lastUpdatedLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> lastUpdatedBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdated',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'quickSummary',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'quickSummary',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> quickSummaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> quickSummaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quickSummary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'quickSummary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition> quickSummaryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'quickSummary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quickSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'quickSummary',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'quickSummaryRange',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'quickSummaryRange',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quickSummaryRange',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'quickSummaryRange',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'quickSummaryRange',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quickSummaryRange',
        value: '',
      ));
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterFilterCondition>
      quickSummaryRangeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'quickSummaryRange',
        value: '',
      ));
    });
  }
}

extension AiSummaryQueryObject
    on QueryBuilder<AiSummary, AiSummary, QFilterCondition> {}

extension AiSummaryQueryLinks
    on QueryBuilder<AiSummary, AiSummary, QFilterCondition> {}

extension AiSummaryQuerySortBy on QueryBuilder<AiSummary, AiSummary, QSortBy> {
  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByBookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByChunkSummariesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkSummariesJson', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy>
      sortByChunkSummariesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkSummariesJson', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByGlobalSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalSummary', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByGlobalSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalSummary', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByQuickSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummary', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByQuickSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummary', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> sortByQuickSummaryRange() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummaryRange', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy>
      sortByQuickSummaryRangeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummaryRange', Sort.desc);
    });
  }
}

extension AiSummaryQuerySortThenBy
    on QueryBuilder<AiSummary, AiSummary, QSortThenBy> {
  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByBookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByChunkSummariesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkSummariesJson', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy>
      thenByChunkSummariesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkSummariesJson', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByGlobalSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalSummary', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByGlobalSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'globalSummary', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByQuickSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummary', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByQuickSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummary', Sort.desc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy> thenByQuickSummaryRange() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummaryRange', Sort.asc);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QAfterSortBy>
      thenByQuickSummaryRangeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quickSummaryRange', Sort.desc);
    });
  }
}

extension AiSummaryQueryWhereDistinct
    on QueryBuilder<AiSummary, AiSummary, QDistinct> {
  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bookId');
    });
  }

  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByChunkSummariesJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkSummariesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByGlobalSummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'globalSummary',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByQuickSummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quickSummary', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AiSummary, AiSummary, QDistinct> distinctByQuickSummaryRange(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quickSummaryRange',
          caseSensitive: caseSensitive);
    });
  }
}

extension AiSummaryQueryProperty
    on QueryBuilder<AiSummary, AiSummary, QQueryProperty> {
  QueryBuilder<AiSummary, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AiSummary, int, QQueryOperations> bookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bookId');
    });
  }

  QueryBuilder<AiSummary, String?, QQueryOperations>
      chunkSummariesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkSummariesJson');
    });
  }

  QueryBuilder<AiSummary, String?, QQueryOperations> globalSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'globalSummary');
    });
  }

  QueryBuilder<AiSummary, DateTime?, QQueryOperations> lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<AiSummary, String?, QQueryOperations> quickSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quickSummary');
    });
  }

  QueryBuilder<AiSummary, String?, QQueryOperations>
      quickSummaryRangeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quickSummaryRange');
    });
  }
}
