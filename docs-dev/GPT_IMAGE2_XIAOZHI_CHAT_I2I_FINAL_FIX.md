# GPT_IMAGE2_XIAOZHI_CHAT_I2I_FINAL_FIX

## Final Verification

Task: `P1-XIAOZHI-GPT-IMAGE2-CHAT-I2I-VERIFY-AND-CLEANUP`

Date: 2026-05-20

Scope: verify only, minimal cleanup, docs update. No rewrite of `third_party_image_api.ts`; no `/images/edits` or `multipart_edits` retry; no `ai.ts`, DB schema, `package.json`, or lockfile changes; no `git add`, commit, or push.

## Provider Mode

The working provider mode is:

```text
xiaozhi_chat_i2i
```

For `providerMode=xiaozhi_chat_i2i`:

- Text-to-image with no reference image keeps the current generations route.
- Image-to-image with `referenceList.length > 0` uses `POST /v1/chat/completions`.
- This mode is separate from `openai_images`, `multipart_edits`, and `json_base64_edits`.

## Request Shape

Image-to-image sends JSON with `Content-Type: application/json`:

```json
{
  "model": "gpt-image-2",
  "async": true,
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "<prompt>" },
        { "type": "image_url", "image_url": { "url": "<data-url-or-http-url>" } }
      ]
    }
  ]
}
```

Reference image field path:

```text
messages[0].content[1].image_url.url
```

`async` is `true`, but this xiaozhi response does not require polling. The usable image URL is returned synchronously in:

```text
choices[0].message.content
```

## URL Extraction

Primary markdown image URL regex:

```regex
/!\[[^\]]*\]\((https?:\/\/[^)]+)\)/i
```

Bare URL fallback regex:

```regex
/(https?:\/\/\S+\.(png|jpg|jpeg|webp))/i
```

If neither pattern matches, the vendor code throws:

```text
xiaozhi chat i2i response schema not recognized
```

## Zero-byte Protection

The implementation downloads/normalizes the extracted image and calls the existing non-empty image guard. Images below 1024 bytes are rejected as success results, preventing 0-byte output from being accepted or saved.

Verified output file:

```text
Toonflow-app/data/oss/testImage.jpg
Length: 1480537
```

## Source Checks

- `Toonflow-app/data/vendor/third_party_image_api.ts`
  - `providerMode=xiaozhi_chat_i2i` exists.
  - With references, routes to `/chat/completions`.
  - Sends `model`, `async: true`, and `messages[].content[]` with `text` plus `image_url`.
  - Parses `choices[0].message.content`.
  - Extracts markdown image URL first, bare image URL second.
  - Downloads/normalizes image and rejects images smaller than 1024 bytes.
- `Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts`
  - Accepts `imageBase64`.
  - Builds `referenceList = [{ type: "image", base64: imageBase64 }]`.
  - Logs `clientRequestId`, `modelName`, `providerMode`, and endpoint diagnostic context.
- `Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue`
  - Image-to-image tab sends `imageBase64`.
  - `loading` and `inFlight` prevent concurrent submission.
  - Error toast includes `[clientRequestId] [modelName]`.
- `Toonflow-web/src/components/setting/components/vendorConfig.vue`
  - Documents `providerMode=xiaozhi_chat_i2i`.
  - Provides it in the provider mode select options.
- `tools/dev/verify-gpt-image2-xiaozhi-chat.ps1`
  - Verifies both text-to-image and image-to-image.
  - Verifies `1:1`, `16:9`, and `9:16` for both text-to-image and image-to-image.
  - Reports `providerMode`, `endpointUsed`, `requestModel`, `responseModel`, `requestModelUnchanged`, `extractedImageUrl`, `imageBytes`, and `success/failure`.

## Model Name Lock

Hard requirement: Toonflow must keep the user-selected request model unchanged when calling the upstream xiaozhi API.

Required request model:

```text
requestModel = gpt-image-2
```

Forbidden request model rewrites:

```text
gpt-image-2-1k
gpt-image-2-2k
gpt-image-2-4k
gpt-image-2-1k-1x1
firefly-gpt-image-2-1k-1x1
any model name with size / aspect-ratio / resolution suffixes
```

Aspect ratio and size must stay in independent request parameters such as:

```text
aspectRatio
aspect_ratio
size
openAiSize
image_size
```

Current Toonflow behavior:

- `imageTest.ts` receives `modelName` from the request body and calls `u.Ai.Image(`${id}:${modelName}`)`.
- `third_party_image_api.ts` sends `model: model.modelName`.
- For `xiaozhi_chat_i2i`, vendor logs `requestModel=${model.modelName}`.
- `responseModel` is read from xiaozhi's response and is logged only as response metadata.

Important distinction:

```text
requestModel = gpt-image-2
responseModel may be firefly-gpt-image-2-1k-1x1 / firefly-gpt-image-2-1k-3x4 / another xiaozhi internal route name
responseModel does not mean Toonflow rewrote the local request model
responseModel must not be written back into requestModel
```

## Verification Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/start-toonflow-dev.ps1 -Mode restart -Force
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/verify-gpt-image2-xiaozhi-chat.ps1
```

Dev restart result:

```text
Backend ready: http://localhost:10588
Frontend ready: http://localhost:50188
```

The first verification attempt hit backend `ERR_DLOPEN_FAILED`. Recovery was limited to:

```powershell
cd Toonflow-app
npm rebuild better-sqlite3
```

No dependency manifest was edited.

## Latest Verification Result

Timestamp:

```text
2026-05-20T21:35:25.6703753+08:00
```

Report file:

```text
.toonflow-dev/gpt-image2-xiaozhi-chat-last-run.json
```

Top-level model-name lock result:

```text
expectedRequestModel: gpt-image-2
requestModelUnchanged: true
```

### Text-to-image Matrix

```text
1:1   openAiSize=1024x1024 endpointUsed=/images/generations requestModel=gpt-image-2 requestModelUnchanged=true imageBytes=1287654 success=true
16:9  openAiSize=1792x1024 endpointUsed=/images/generations requestModel=gpt-image-2 requestModelUnchanged=true imageBytes=1339976 success=true
9:16  openAiSize=1024x1792 endpointUsed=/images/generations requestModel=gpt-image-2 requestModelUnchanged=true imageBytes=1464265 success=true
```

### Image-to-image Matrix

```text
1:1   openAiSize=1024x1024 endpointUsed=/chat/completions requestModel=gpt-image-2 responseModel=firefly-gpt-image-2-1k-3x4 requestModelUnchanged=true imageBytes=1911432 success=true
16:9  openAiSize=1792x1024 endpointUsed=/chat/completions requestModel=gpt-image-2 responseModel=firefly-gpt-image-2-1k-3x4 requestModelUnchanged=true imageBytes=1911432 success=true
9:16  openAiSize=1024x1792 endpointUsed=/chat/completions requestModel=gpt-image-2 responseModel=firefly-gpt-image-2-1k-3x4 requestModelUnchanged=true imageBytes=1911432 success=true
```

## Lint and Type-check

`yarn` was not available in the current shell, so the same scripts were run with `npm run`.

```text
Toonflow-app: npm run lint -> pass (tsc --noEmit)
Toonflow-web: npm run type-check -> fail
```

The frontend type-check failure is pre-existing/unrelated to this xiaozhi chain:

```text
src/views/production/components/workbench/generate copy.vue(1063,1): error TS1109: Expression expected.
```

## Final Answers

1. providerMode name: `xiaozhi_chat_i2i`
2. Text-to-image endpointUsed: `/images/generations`
3. Image-to-image endpointUsed: `/chat/completions`
4. Content-Type: `application/json`
5. Reference image field path: `messages[0].content[1].image_url.url`
6. async: `true`
7. Polling required: no
8. Image URL extracted from: `choices[0].message.content`
9. Markdown image URL regex: `/!\[[^\]]*\]\((https?:\/\/[^)]+)\)/i`
10. Bare URL fallback regex: `/(https?:\/\/\S+\.(png|jpg|jpeg|webp))/i`
11. Text-to-image success: yes
12. Image-to-image success: yes
13. Final image bytes: text-to-image `1385245`; image-to-image `1911432`; saved OSS file `1480537`
14. 0-byte image produced: no
15. `ai.ts` modified: no
16. DB schema modified: no
17. `package.json` / `yarn.lock` modified: no
18. lint/type-check: app lint passed; web type-check failed at unrelated `generate copy.vue(1063,1)`
19. Model-name lock: `requestModel=gpt-image-2` for text-to-image `1:1` / `16:9` / `9:16` and image-to-image `1:1` / `16:9` / `9:16`; `requestModelUnchanged=true`
20. Rollback command:

```powershell
git checkout -- Toonflow-app/data/vendor/third_party_image_api.ts
git checkout -- Toonflow-app/src/routes/setting/vendorConfig/modelTest/imageTest.ts
git checkout -- Toonflow-web/src/components/setting/components/vendorConfig.vue
git checkout -- Toonflow-web/src/components/setting/components/vendorTest/ImageModelTest.vue
Remove-Item tools/dev/verify-gpt-image2-xiaozhi-chat.ps1 -ErrorAction SilentlyContinue
Remove-Item docs-dev/GPT_IMAGE2_XIAOZHI_CHAT_I2I_FINAL_FIX.md -ErrorAction SilentlyContinue
```
