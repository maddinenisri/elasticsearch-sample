package com.mdstech.sample;

import com.mdstech.sample.service.ElasticSearchClientService;
import static org.junit.Assert.assertNotNull;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment= SpringBootTest.WebEnvironment.RANDOM_PORT,
        classes = {Application.class})
public class ApplicationTest {

    @Autowired
    private ElasticSearchClientService elasticSearchClientService;

    @Test
    public void testContextInitialize() {
        assertNotNull(elasticSearchClientService);
    }
}
