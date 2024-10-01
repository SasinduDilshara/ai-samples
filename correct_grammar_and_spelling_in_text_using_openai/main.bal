import ballerina/http;
import ballerina/io;
import ballerinax/openai.chat;

configurable string openAIToken = ?;

public function main(string filePath) returns error? {
    http:RetryConfig retryConfig = {
        interval: 5, // Initial retry interval in seconds.
        count: 3, // Number of retry attempts before stopping.
        backOffFactor: 2.0 // Multiplier of the retry interval.
    };
    final chat:Client openAIChat = check new ({auth: {token: openAIToken}, retryConfig});

    chat:CreateChatCompletionRequest request = {
        model: "gpt-4o-mini",
        messages: [
            {
                "role": "user",
                "content": string `Fix grammar and spelling mistakes of the content ${check
                io:fileReadString(filePath)}`
            }
        ]
    };

    chat:CreateChatCompletionResponse response = check openAIChat->/chat/completions.post(request);
    string? text = response.choices[0].message.content;

    if text is () {
        return error("Failed to correct grammar and spelling in the given text.");
    }
    io:println(string `Corrected: ${text}`);
}
