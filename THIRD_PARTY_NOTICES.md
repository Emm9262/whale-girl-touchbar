# Third-party notices

The top-level MIT license covers this repository's original code and the original calico-sprite contribution, to the extent project contributors can grant those rights. It does not replace the licenses or conditions attached to third-party code, animation, artwork, characters, dependencies, or trademarks.

## PC2005-cloud/dsh-pet

- Project: <https://github.com/PC2005-cloud/dsh-pet>
- Pinned source: `v0.3.8`, commit `593b9b0785f883630243ef6213542f4603ef69ad`.
- Code: MIT, Copyright (c) 2026 PC2005-cloud. The optional host bridge depends on npm package `dsh-pet@0.3.8`.
- Assets: the upstream v0.3.8 README separately permits open-source use of animation, prompts, and source videos, prohibits commercial use, and requires a link to the original repository wherever a derivative work is introduced, shown, or distributed.
- Terms at the pinned version: <https://github.com/PC2005-cloud/dsh-pet/blob/v0.3.8/README.md#许可>.

The 28 PNG atlases in `Resources/pc2005-assets/` are transparent, sampled adaptations of selected original clips. The original clip durations remain available in the action library. A stable side-running interval is used during actual horizontal movement. No new ownership of the original animation or character is claimed.

The bundled `COPYRIGHT-AND-LICENSE.txt`, `SOURCE.txt`, and `manifest.json` retain upstream attribution, source identities, and provenance. When redistributing this application or using its pictures in a project page, retain the link above and the applicable non-commercial asset conditions. Do not describe this asset collection as MIT artwork.

## vlln/whale-girl

- Project: <https://github.com/vlln/whale-girl>
- Pinned commit: `4b4350478c82d22d506a93567e52ab0ff90c2585`.
- Repository license: MIT, Copyright (c) 2026 Sam Gao (vlln).
- Included work: the original sprite collection under `Resources/whale-girl-assets/` and behavior-derived logic identified in source comments.
- License text: `Resources/whale-girl-LICENSE.txt`.
- Character attribution recorded by the upstream project: ZipZipPipe.

The original project license and attribution are retained. A software license does not grant unrelated trademark rights or imply endorsement by the character designer.

## Cat companion and application icon

`Resources/calico-cat-atlas.png` was created with AI assistance as original companion artwork for this port. It is a 4-by-3 atlas containing idle, walk and run frames. The source artwork was selected as the calico picture-book appearance; no old oneko sprite is included.

The original calico-sprite contribution is provided under the MIT terms in `LICENSE`, to the extent project contributors can grant those rights. This grant does not expand rights in third-party characters, upstream animation or the derivative application icon.

`Resources/WhaleGirl.icns` was created with AI assistance using the existing whale-girl appearance as a reference. It is a derivative character illustration, not an official DeepSeek or upstream project icon. This repository does not claim exclusive rights over the whale-girl identity or remove any underlying character restrictions.

## Apple frameworks and DeepSeek Harness

Cocoa, Foundation, QuartzCore and macOS Touch Bar services are supplied by the operating system and are not redistributed here. The app uses private Touch Bar interfaces checked at runtime, so future macOS compatibility is not guaranteed.

DSH and its runtime dependencies are installed separately by the user. Their own licenses and service terms apply. No user credentials, account profile or model access is bundled with this project.
