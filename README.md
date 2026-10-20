# W1NDY CFG для iOS

Клиент W1NDY CFG для iPhone (iOS 15+): VPN по ключу доступа и режим «только DNS».

Сборка — GitHub Actions (`.github/workflows/ios.yml`): ядро sing-box собирается в `Libbox.xcframework`,
проект генерируется XcodeGen, на выходе — неподписанный `.ipa` (подписывается своим сертификатом;
профиль должен включать Network Extensions → Packet Tunnel).

Исходный код распространяется по лицензии GPL-3.0. Ядро — [sing-box](https://github.com/SagerNet/sing-box) (GPL-3.0),
код сетевого расширения основан на [sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple) (GPL-3.0).
Проект не связан с авторами sing-box.
