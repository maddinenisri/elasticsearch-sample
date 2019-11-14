package com.mdstech.sample.service;

import org.apache.lucene.search.join.ScoreMode;
import org.elasticsearch.action.search.SearchRequest;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.RequestOptions;
import org.elasticsearch.client.RestHighLevelClient;
import org.elasticsearch.index.query.InnerHitBuilder;
import org.elasticsearch.index.query.QueryBuilders;
import org.elasticsearch.join.query.JoinQueryBuilders;
import org.elasticsearch.script.ScriptType;
import org.elasticsearch.script.mustache.SearchTemplateRequest;
import org.elasticsearch.script.mustache.SearchTemplateRequestBuilder;
import org.elasticsearch.script.mustache.SearchTemplateResponse;
import org.elasticsearch.search.SearchHit;
import org.elasticsearch.search.builder.SearchSourceBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.util.FileCopyUtils;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ElasticSearchClientService {

    @Value("classpath:templates/parent-query.json")
    private Resource parentQueryResource;

    private final RestHighLevelClient restHighLevelClient;

    public ElasticSearchClientService(RestHighLevelClient restHighLevelClient) {
        this.restHighLevelClient = restHighLevelClient;
    }

    public String asString(Resource resource) {
        try (Reader reader = new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8)) {
            return FileCopyUtils.copyToString(reader);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public List<SearchHit> getResults(Map<String, Object> parameters) throws Exception {
        String scriptTemplate = asString(parentQueryResource);
        SearchTemplateRequest request = new SearchTemplateRequest();
        request.setRequest(new SearchRequest("music"));
        request.setScriptType(ScriptType.INLINE);
        request.setScript(scriptTemplate);
        Map<String, Object> scriptParams = new HashMap<>();
        scriptParams.put("field", "name");
        scriptParams.put("value", "John Legend");
        request.setScriptParams(scriptParams);
        SearchTemplateResponse response = restHighLevelClient.searchTemplate(request, RequestOptions.DEFAULT);
        return covertToResults(response.getResponse());
    }

    public List<SearchHit> getResults() throws Exception {
        SearchRequest searchRequest = buildSearchRequest();
        SearchSourceBuilder searchSourceBuilder = new SearchSourceBuilder().query(JoinQueryBuilders
                .hasParentQuery("artist",
                        QueryBuilders.matchQuery("name", "John Legend"),
                        false).innerHit(new InnerHitBuilder()));
        searchRequest.source(searchSourceBuilder).searchType(SearchType.QUERY_THEN_FETCH);
        SearchResponse searchResponse = restHighLevelClient.search(searchRequest, RequestOptions.DEFAULT);
        return covertToResults(searchResponse);
    }

    private List<SearchHit> covertToResults(SearchResponse searchResponse) {
        SearchHit[] searchHits = searchResponse.getHits().getHits();
        List<SearchHit> data = Arrays.stream(searchHits).collect(Collectors.toList());
        return data;
    }

    private SearchRequest buildSearchRequest() {
        SearchRequest searchRequest = new SearchRequest();
        searchRequest.indices("music");
        return searchRequest;
    }
}
