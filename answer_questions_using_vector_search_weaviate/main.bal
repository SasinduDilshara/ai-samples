import ballerina/http;
import ballerina/io;
import ballerinax/openai.embeddings;
import ballerinax/weaviate;

configurable string openAIToken = ?;
configurable string weaviateToken = ?;
configurable string weaviateURL = ?;

const CLASS_NAME = "QuestionAnswerStore";
const MODEL = "text-embedding-3-small";

final embeddings:Client openai = check new ({auth: {token: openAIToken}});
final weaviate:Client weaviate = check new ({auth: {token: weaviateToken}}, weaviateURL);

service / on new http:Listener(8080) {
    resource function get answer(string question) returns weaviate:JsonObject|error? {
        // Retrieve OpenAI embeddings for the input question
        embeddings:CreateEmbeddingResponse embeddingResponse = check openai->/embeddings.post({
                model: MODEL,
                input: question
            }
        );
        float[] vector = embeddingResponse.data[0].embedding;

        // Querying Weaviate for the closest vector using GraphQL
        string graphQLQuery = string `{
                                    Get {
                                        ${CLASS_NAME} (
                                        nearVector: {
                                            vector: ${vector.toString()}
                                            }
                                            limit: 1
                                        ){
                                        question
                                        answer
                                        _additional {
                                            certainty,
                                            id
                                            }
                                        }
                                    }
                                }`;

        weaviate:GraphQLResponse results = check weaviate->/graphql.post({query: graphQLQuery});
        io:println("Results: ", results);
        return results.data;
    }
}
