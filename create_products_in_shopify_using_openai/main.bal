import ballerina/http;
import ballerinax/googleapis.sheets;
import ballerinax/openai.chat;
import ballerinax/openai.images;
import ballerinax/shopify.admin as shopify;

configurable string sheetsAccessToken = ?;
configurable string googleSheetId = ?;

configurable string openAIToken = ?;

configurable string shopifyToken = ?;
configurable string shopifyStoreURL = ?;

final chat:Client openAIChat = check new ({auth: {token: openAIToken}});
final images:Client openAIImages = check new ({auth: {token: openAIToken}});
final sheets:Client gsheets = check new ({auth: {token: sheetsAccessToken}});
final shopify:Client shopify = check new (apiKeyConfig = {xShopifyAccessToken: shopifyToken}, serviceUrl = shopifyStoreURL);

service / on new http:Listener(9090) {
    resource function post products() returns int|error {
        // Get the product details from the last inserted row of the Google Sheet.
        sheets:Range range = check gsheets->getRange(googleSheetId, "Sheet1", "A2:F");
        var [name, benefits, features, productType] = getProduct(range);

        // Generate a product description from OpenAI for a given product name.
        string query = string `generate a product descirption in 250 words about ${name}`;
        chat:CreateChatCompletionRequest request = {
            model: "gpt-4o",
            messages: [
                {
                    "role": "user",
                    "content": query
                }
            ],
            max_tokens: 100
        };

        chat:CreateChatCompletionResponse completionRes = check openAIChat->/chat/completions.post(request);

        // Generate a product image from OpenAI for the given product.
        images:CreateImageRequest imagePrmt = {prompt: string `${name}, ${benefits}, ${features}`};
        images:ImagesResponse imageRes = check openAIImages->/images/generations.post(imagePrmt);

        // Create a product in Shopify.
        shopify:CreateProduct product = {
            product: {
                title: name,
                body_html: completionRes.choices[0].message.content,
                tags: features,
                product_type: productType,
                images: [{src: imageRes.data[0].url}]
            }
        };
        shopify:ProductObject prodObj = check shopify->createProduct(product);
        int? pid = prodObj?.product?.id;
        if pid is () {
            return error("Error in creating product in Shopify");
        }
        return pid;
    }
}

function getProduct(sheets:Range range) returns [string, string, string, string] {
    int lastRowIndex = range.values.length() - 1;
    (int|string|decimal)[] row = range.values[lastRowIndex];
    return [<string>row[0], <string>row[1], <string>row[2], <string>row[3]];
}
