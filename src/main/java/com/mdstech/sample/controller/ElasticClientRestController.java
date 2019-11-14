package com.mdstech.sample.controller;

import com.mdstech.sample.service.ElasticSearchClientService;
import org.elasticsearch.search.SearchHit;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class ElasticClientRestController {

    private ElasticSearchClientService elasticSearchClientService;

    public ElasticClientRestController(ElasticSearchClientService elasticSearchClientService) {
        this.elasticSearchClientService = elasticSearchClientService;
    }

    @GetMapping(path = "/api/v1/results")
    public List<SearchHit> getResults() throws Exception {
        return elasticSearchClientService.getResults();
    }

    @GetMapping(path = "/api/v2/results")
    public List<SearchHit> getResultsByParams() throws Exception {
        return elasticSearchClientService.getResults(null);
    }

}
