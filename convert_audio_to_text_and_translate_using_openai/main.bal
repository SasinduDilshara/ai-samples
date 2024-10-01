import ballerina/http;
import ballerina/io;
import ballerinax/openai.audio;
import ballerinax/openai.chat;

configurable string openAIToken = ?;

const string AUDIO_FILE = "german_hello.mp3";
const string AUDIO_FILE_PATH = "./audo_clips/" + AUDIO_FILE;

public function main(string audioURL, string toLanguage) returns error? {
    // Creates a HTTP client to download the audio file
    http:Client audioEP = check new (audioURL);
    http:Response httpResp = check audioEP->get("");
    byte[] audioBytes = check httpResp.getBinaryPayload();
    check io:fileWriteBytes(AUDIO_FILE_PATH, audioBytes);

    // Creates a request to translate the audio file to text (English)
    audio:CreateTranslationRequest translationsReq = {
        file: {fileContent: check io:fileReadBytes(AUDIO_FILE_PATH), fileName: AUDIO_FILE},
        model: "whisper-1"
    };

    // Translates the audio file to text (English)
    audio:Client openAIAudio = check new ({auth: {token: openAIToken}});
    audio:CreateTranscriptionResponse transcriptionRes = check openAIAudio->/audio/translations.post(translationsReq);
    io:println("Audio text in English: ", transcriptionRes.text);

    final chat:Client openAIChat = check new ({
        auth: {
            token: openAIToken
        }
    });

    string query = string `Translate the following text from English to ${toLanguage} : ${transcriptionRes.text}`;

    // Creates a request to translate the text from English to another language
    chat:CreateChatCompletionRequest request = {
        model: "gpt-4o",
        messages: [
            {
                "role": "user",
                "content": query
            }
        ],
        temperature: 0.7,
        max_tokens: 256,
        top_p: 1,
        frequency_penalty: 0,
        presence_penalty: 0
    };

    // Translates the text from English to another language
    chat:CreateChatCompletionResponse response = check openAIChat->/chat/completions.post(request);
    string? translatedText = response.choices[0].message.content;

    if translatedText is () {
        return error("Failed to translate the given audio.");
    }
    io:println("Translated text: ", translatedText);
}
