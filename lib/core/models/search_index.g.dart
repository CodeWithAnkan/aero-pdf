// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_index.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSearchIndexCollection on Isar {
  IsarCollection<SearchIndex> get searchIndexs => this.collection();
}

const SearchIndexSchema = CollectionSchema(
  name: r'SearchIndex',
  id: 4768691469594422700,
  properties: {
    r'bookId': PropertySchema(
      id: 0,
      name: r'bookId',
      type: IsarType.long,
    ),
    r'isOcr': PropertySchema(
      id: 1,
      name: r'isOcr',
      type: IsarType.bool,
    ),
    r'pageNumber': PropertySchema(
      id: 2,
      name: r'pageNumber',
      type: IsarType.long,
    ),
    r'pageText': PropertySchema(
      id: 3,
      name: r'pageText',
      type: IsarType.string,
    )
  },
  estimateSize: _searchIndexEstimateSize,
  serialize: _searchIndexSerialize,
  deserialize: _searchIndexDeserialize,
  deserializeProp: _searchIndexDeserializeProp,
  idName: r'id',
  indexes: {
    r'pageText': IndexSchema(
      id: -8267714053162140240,
      name: r'pageText',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'pageText',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _searchIndexGetId,
  getLinks: _searchIndexGetLinks,
  attach: _searchIndexAttach,
  version: '3.1.0+1',
);

int _searchIndexEstimateSize(
  SearchIndex object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.pageText.length * 3;
  return bytesCount;
}

void _searchIndexSerialize(
  SearchIndex object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bookId);
  writer.writeBool(offsets[1], object.isOcr);
  writer.writeLong(offsets[2], object.pageNumber);
  writer.writeString(offsets[3], object.pageText);
}

SearchIndex _searchIndexDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SearchIndex();
  object.bookId = reader.readLong(offsets[0]);
  object.id = id;
  object.isOcr = reader.readBool(offsets[1]);
  object.pageNumber = reader.readLong(offsets[2]);
  object.pageText = reader.readString(offsets[3]);
  return object;
}

P _searchIndexDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _searchIndexGetId(SearchIndex object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _searchIndexGetLinks(SearchIndex object) {
  return [];
}

void _searchIndexAttach(
    IsarCollection<dynamic> col, Id id, SearchIndex object) {
  object.id = id;
}

extension SearchIndexQueryWhereSort
    on QueryBuilder<SearchIndex, SearchIndex, QWhere> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SearchIndexQueryWhere
    on QueryBuilder<SearchIndex, SearchIndex, QWhereClause> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> idBetween(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> pageTextEqualTo(
      String pageText) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pageText',
        value: [pageText],
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterWhereClause> pageTextNotEqualTo(
      String pageText) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageText',
              lower: [],
              upper: [pageText],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageText',
              lower: [pageText],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageText',
              lower: [pageText],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pageText',
              lower: [],
              upper: [pageText],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SearchIndexQueryFilter
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> bookIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bookId',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      bookIdGreaterThan(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> bookIdLessThan(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> bookIdBetween(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> idBetween(
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

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> isOcrEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isOcr',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageNumberGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageNumberLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> pageTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> pageTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pageText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition> pageTextMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pageText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageText',
        value: '',
      ));
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterFilterCondition>
      pageTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pageText',
        value: '',
      ));
    });
  }
}

extension SearchIndexQueryObject
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {}

extension SearchIndexQueryLinks
    on QueryBuilder<SearchIndex, SearchIndex, QFilterCondition> {}

extension SearchIndexQuerySortBy
    on QueryBuilder<SearchIndex, SearchIndex, QSortBy> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByBookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByIsOcr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOcr', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByIsOcrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOcr', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByPageNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageNumber', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByPageNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageNumber', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByPageText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageText', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> sortByPageTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageText', Sort.desc);
    });
  }
}

extension SearchIndexQuerySortThenBy
    on QueryBuilder<SearchIndex, SearchIndex, QSortThenBy> {
  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByBookIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bookId', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsOcr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOcr', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByIsOcrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isOcr', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByPageNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageNumber', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByPageNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageNumber', Sort.desc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByPageText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageText', Sort.asc);
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QAfterSortBy> thenByPageTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageText', Sort.desc);
    });
  }
}

extension SearchIndexQueryWhereDistinct
    on QueryBuilder<SearchIndex, SearchIndex, QDistinct> {
  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByBookId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bookId');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByIsOcr() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isOcr');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByPageNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageNumber');
    });
  }

  QueryBuilder<SearchIndex, SearchIndex, QDistinct> distinctByPageText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageText', caseSensitive: caseSensitive);
    });
  }
}

extension SearchIndexQueryProperty
    on QueryBuilder<SearchIndex, SearchIndex, QQueryProperty> {
  QueryBuilder<SearchIndex, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SearchIndex, int, QQueryOperations> bookIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bookId');
    });
  }

  QueryBuilder<SearchIndex, bool, QQueryOperations> isOcrProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isOcr');
    });
  }

  QueryBuilder<SearchIndex, int, QQueryOperations> pageNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageNumber');
    });
  }

  QueryBuilder<SearchIndex, String, QQueryOperations> pageTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageText');
    });
  }
}
