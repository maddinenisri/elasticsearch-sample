const AWS = require('aws-sdk');
const path = require('path');
const creds = new AWS.EnvironmentCredentials('AWS');
const converter = AWS.DynamoDB.Converter.unmarshall;
const indexMap = {
  artist: "music",
  song: "music"
}
const esDomain = {
    endpoint: process.env.ES_ENDPOINT,
    region: process.env.ES_REGION,
    doctype: '_doc'
};
const endpoint =  new AWS.Endpoint(esDomain.endpoint);
const httpClient = new AWS.HttpClient();
exports.handler = (event, context, callback) => {
  event.Records.forEach(record => {
    switch(record.eventName) {
      case 'REMOVE': {
        // const httpURI =
        console.log(record.dynamodb.Keys);
      }
      case 'MODIFY':
      case 'INSERT': {
        const doc = converter(record.dynamodb.NewImage);
        let routing = ''
        if(doc.entityType === 'artist') {
          doc['relationLink'] = {
            name: 'artist'
          }
        }
        else if(doc.entityType === 'song') {
          doc['relationLink'] = {
            name: 'song',
            parent: doc.payload.artist.entityId
          };
          routing = '?routing='+doc.payload.artist.entityId
        }
        if(indexMap[doc.entityType] !== undefined) {
          const httpURI = path.join('/', indexMap[doc.entityType], esDomain.doctype, doc.entityId) + routing;
          const postPromise = processRequest(doc, httpURI, 'POST');
          postPromise.then(data => {
            console.log(data);
          }).catch(err => {
            console.log(err);
          });
        }
      }
    }
  });
}

function deleteIndex() {
  processRequest({}, path.join('/', 'music'), 'DELETE');
}

function createIndex() {
  const doc = {};
  doc["mappings"] = {
    properties: {
      relationLink: {
        type: "join",
        "relations": {
          "artist": "song"
        }
      }
    }
  };
  processRequest(doc, path.join('/', 'music'), 'PUT');
}

function processRequest(doc, httpURI, httpMethod) {
  return new Promise((resolve, reject) => {
    // console.log(doc);
    const request = new AWS.HttpRequest(endpoint);
    request.method = httpMethod;
    request.path = httpURI;
    request.region = esDomain.region;
    request.body = JSON.stringify(doc);
    request.headers['presigned-expires'] = false;
    request.headers['Content-Type'] = "application/json";
    request.headers['Host'] = endpoint.host;
    request.headers['Content-Length'] = Buffer.byteLength(request.body);

    // AWS V4 Sign request
    const signer = new AWS.Signers.V4(request, 'es');
    signer.addAuthorization(creds, new Date());

    httpClient.handleRequest(request, null, response => {
      const { statusCode, statusMessage, headers } = response;
      let body = '';
      response.on('data', chunk => {
        body += chunk;
      });
      response.on('end', () => {
        const data = {
          statusCode,
          statusMessage,
          headers
        };
        if (body) {
          data.body = JSON.parse(body);
        }
        console.log(data);
        resolve(data);
      });
    },
    err => {
      console.log('Error: ' + err);
      reject(err);
    });
  });
}
