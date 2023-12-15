# FileDrop

A Simple file transfering app. It made with Flutter. It works on local networks.

## Screenshots

<img style="height: 30%; width: 30%" alt='Screenshot 0' src='screenshots_en/Google Pixel 4 XL Screenshot 0.png'/> <img style="height: 30%; width: 30%" alt='Screenshot 1' src='screenshots_en/Google Pixel 4 XL Screenshot 1.png'/> <img style="height: 30%; width: 30%" alt='Screenshot 2' src='screenshots_en/Google Pixel 4 XL Screenshot 2.png'/>

## Why?
Because most of the other file transfering apps on Play Store has bloated with ads or poor reviews, so i decied to develop an useful app and gain experience.
## Download and Install
### Ubuntu, Debian
You can get .deb packages from <a href="https://github.com/iamalper/weepy/releases">Releases</a>
### Android
<a href='https://play.google.com/store/apps/details?id=com.alper.weepy&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img style="height: 40%; width: 40%" alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png'/></a>

Or you can get **.apk** or **.aab** packages from <a href="https://github.com/iamalper/weepy/releases">Releases</a>
### Windows
Windows packages not tested, but you can get them  from <a href="https://github.com/iamalper/weepy/releases">Releases</a> in windows.zip

*For other platforms, PR's welcomed but i don't have any plans to support them.*
## Build
It is a flutter project so if you have **flutter** installed, you can build with `flutter build` from repo directory.
If not, see <a href=https://docs.flutter.dev/get-started/install>Flutter docs: Install</a>

For Android release build, you need to create your keystore and **key.properties** in **android** folder. See more at <a href=https://docs.flutter.dev/deployment/android#signing-the-app>Flutter docs: Signing android app</a>

Also you can set your **lib/firebase_options.dart** or crash reports will sent to my firebase console.
## Contribution
Thank you, if you are interesting for contributing.

Any PR or ideas welcomed. Please commit to develop branch. I am keeping main branch more stable and automatically published to Google Play testers.

You can contribute with solving issues from Issues tab, tweaking UI, improving translations or translating another languages (with committing in **lib/l10** folder).
