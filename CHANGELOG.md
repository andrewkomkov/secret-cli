# Changelog

## [1.8.0](https://github.com/andrewkomkov/secret-cli/compare/v1.7.1...v1.8.0) (2026-11-14)


### Features

* **cookie:** translate the Safari extension into Russian ([55bf33e](https://github.com/andrewkomkov/secret-cli/commit/55bf33e42be7091f861b7f0708bb7d6c4b4ffa23))
* **ls:** find secrets by meaning with the on-device model ([546694f](https://github.com/andrewkomkov/secret-cli/commit/546694f03469606fe266d3b3d321942281b4bfc6))
* **ls:** find secrets by meaning with the on-device model ([b28025b](https://github.com/andrewkomkov/secret-cli/commit/b28025b9eed36c8ae1eeda67742058848e480b85))
* **secretbar:** search in SecretBar from Siri and Spotlight ([2ef3b17](https://github.com/andrewkomkov/secret-cli/commit/2ef3b174c446e0ca5bbc0739681447a276230157))
* **secretbar:** search in SecretBar from Siri and Spotlight ([1692da0](https://github.com/andrewkomkov/secret-cli/commit/1692da0bdd51a2fa8b6666209e82660971ce8d40))
* **store:** post-quantum Secure Enclave store (ML-KEM-768 + P-256) ([d8575a4](https://github.com/andrewkomkov/secret-cli/commit/d8575a49c466c8599379c16548fa604201e842c9))
* **store:** seal values with ML-KEM-768 and P-256 from the Secure Enclave ([c70504e](https://github.com/andrewkomkov/secret-cli/commit/c70504e1f8d8fe3cae489bc232560a43d8ac83ac))


### Bug Fixes

* **secretbar:** build the search intent only with the Xcode 26 SDK ([ae66f1b](https://github.com/andrewkomkov/secret-cli/commit/ae66f1bb589c1ec345d1084c003a2237780413e1))
* **store:** open each value again before touchid pq writes the store ([0527203](https://github.com/andrewkomkov/secret-cli/commit/052720346205200409dd6bfe0895969963965c70))

## [1.7.1](https://github.com/andrewkomkov/secret-cli/compare/v1.7.0...v1.7.1) (2026-11-06)


### Bug Fixes

* **lease:** print the lease end without .first ambiguity ([cf0204f](https://github.com/andrewkomkov/secret-cli/commit/cf0204ff1637e20a9055c4d8c3faff3edd617021))

## [1.7.0](https://github.com/andrewkomkov/secret-cli/compare/v1.6.1...v1.7.0) (2026-11-06)


### Features

* **cookie:** merge jars on import instead of overwriting ([ae36b81](https://github.com/andrewkomkov/secret-cli/commit/ae36b8129c7fe701ed58d2d2a92afa12f308cb5a))
* **lease:** hold leased secrets across screen lock ([6d5b6f3](https://github.com/andrewkomkov/secret-cli/commit/6d5b6f3f6e029e1fae95af3aa9c8d92aa5ddc316))
* **lease:** show the lease in SecretBar ([adf549f](https://github.com/andrewkomkov/secret-cli/commit/adf549fd21920f5b1922d26da680fa5ba3f53490))

## [1.6.1](https://github.com/andrewkomkov/secret-cli/compare/v1.6.0...v1.6.1) (2026-11-04)


### Bug Fixes

* **cookie:** extension icon and the cookie-jar run example ([278b169](https://github.com/andrewkomkov/secret-cli/commit/278b16935fed0cc8638c0880d63fcd8f499e3cdc))
* **cookie:** keep extension entitlements so Safari registers it ([ab324ff](https://github.com/andrewkomkov/secret-cli/commit/ab324ff02c8d8add0eb80a7f9d93311e02c41ba3))

## [1.6.0](https://github.com/andrewkomkov/secret-cli/compare/v1.5.0...v1.6.0) (2026-11-04)


### Features

* **cookie:** add loopback bridge daemon and Safari extension assets ([15a1a54](https://github.com/andrewkomkov/secret-cli/commit/15a1a545852f5e6362557dd4239a04d13fd7b840))
* **cookie:** build and install the Safari extension app ([d0a1e6f](https://github.com/andrewkomkov/secret-cli/commit/d0a1e6fa7c73cbeaaaefa12cc4edc011f8432d92))

## [1.5.0](https://github.com/andrewkomkov/secret-cli/compare/v1.4.0...v1.5.0) (2026-11-04)


### Features

* **cookie:** add cookie jars with import and run --cookie-jar ([00c0349](https://github.com/andrewkomkov/secret-cli/commit/00c03497a67a6681ceaa00097d112bab56094d34))

## [1.4.0](https://github.com/andrewkomkov/secret-cli/compare/v1.3.0...v1.4.0) (2026-11-03)


### Features

* **cookie:** read cookies from all Safari profiles ([4ae0cb4](https://github.com/andrewkomkov/secret-cli/commit/4ae0cb48c122437913665d53c62c2af536fa24ef))

## [1.3.0](https://github.com/andrewkomkov/secret-cli/compare/v1.2.0...v1.3.0) (2026-11-03)


### Features

* **cookie:** import Safari cookies into the store ([7230a95](https://github.com/andrewkomkov/secret-cli/commit/7230a95e467a513192a12077ff7711c1a0deac5b))

## [1.2.0](https://github.com/andrewkomkov/secret-cli/compare/v1.1.0...v1.2.0) (2026-10-23)


### Features

* add secret version ([536c953](https://github.com/andrewkomkov/secret-cli/commit/536c9536d877b17a9b67955f17c0267ef95764b6))
* **app:** english interface with a russian translation ([966b2e7](https://github.com/andrewkomkov/secret-cli/commit/966b2e73d5cd921a19e9a56f66005a5131fbfd2e))
* **app:** return copies the reference, shift-return the value, add a secret from the menu bar panel ([521b94e](https://github.com/andrewkomkov/secret-cli/commit/521b94ea1a76b0ad585692dd9663bd0c74e0312e))
* **site:** landing page with motion design ([3864e4d](https://github.com/andrewkomkov/secret-cli/commit/3864e4d99a1fad1c7fef8f21016bd6af0834bebb))


### Bug Fixes

* **app:** give the intent dialog an explicit type for older swift ([b038708](https://github.com/andrewkomkov/secret-cli/commit/b038708e70fa68f1907b315b27bd57b8b42d8f19))
* keep install.sh going when launch services refuses to open secretbar ([4be4fb7](https://github.com/andrewkomkov/secret-cli/commit/4be4fb71d2da6d66804368207f436eb21ea7ccfe))
* **site:** raise the contrast of muted text, load fonts without blocking ([7af013d](https://github.com/andrewkomkov/secret-cli/commit/7af013d8e2c5b099d6789b3cfe7590db4e1f524a))
