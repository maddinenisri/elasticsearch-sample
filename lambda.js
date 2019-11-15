const AWS = require('aws-sdk');
const path = require('path');
const creds = new AWS.EnvironmentCredentials('AWS');
const converter = AWS.DynamoDB.Converter.unmarshall;
const indexMap = {
  application: "application",
  subapplication: "application"
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
    const doc = converter(record.dynamodb.NewImage);
    if(indexMap[doc.entityType] !== undefined) {
      postDocumentToES(doc, indexMap[doc.entityType], context);
    }
  });
}

function postDocumentToES(doc, esIndex, context) {
  const request = new AWS.HttpRequest(endpoint);
  request.method = 'POST';
  request.path = path.join('/', esIndex, esDomain.doctype, doc.entityId);
  request.region = esDomain.region;
  request.body = JSON.stringify(doc);
  request.headers['presigned-expires'] = false;
  request.headers['Content-Type'] = "application/json";
  request.headers['Host'] = endpoint.host;

  // Sign the request (Sigv4)
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
      context.succeed('Document added ' + data);
    });
  },
  err => {
    console.log('Error: ' + err);
    context.fail();
  });
}
