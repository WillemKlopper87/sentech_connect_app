# Translations that need native review

Drafts written by the assistant for the contract-sync work (sign-in binding and reference, delete-account re-check, typed problem copy, suspended service). They are **machine-quality first drafts**: a native Afrikaans and a native isiZulu speaker must review every line before release (release gate L3 in the platform's `docs/OWNER_ACTIONS.md`). Placeholders (`{seconds}`, `{minutes}`, `{reference}`) must stay.

Other af and zu strings that still read as English fallbacks are listed by `dart run tool/l10n_coverage.dart`.

| Key | English | Afrikaans (draft) | isiZulu (draft) |
|---|---|---|---|
| `passesStatusSuspended` | Service suspended | Diens opgeskort | Isevisi imisiwe |
| `passesSuspendedNote` | Your provider has paused this service. Contact them to get it back. | Jou verskaffer het hierdie diens gepouseer. Kontak hulle om dit terug te kry. | Umhlinzeki wakho umise le sevisi. Xhumana naye ukuze ibuyiswe. |
| `otpUseSmsReference` | Use the SMS that shows reference {reference}. | Gebruik die SMS wat verwysing {reference} wys. | Sebenzisa i-SMS ekhombisa inkomba {reference}. |
| `failureBindingRequired` | Sign-in could not be completed. Please update the app and try again. | Aanmelding kon nie voltooi word nie. Werk die toepassing op en probeer weer. | Ukungena akukwazanga ukuqedwa. Sicela ubuyekeze uhlelo lokusebenza bese uyazama futhi. |
| `failureHumanVerificationFailed` | We could not confirm that you are a person. Please try again. | Ons kon nie bevestig dat jy 'n mens is nie. Probeer asseblief weer. | Asikwazanga ukuqinisekisa ukuthi ungumuntu. Sicela uzame futhi. |
| `failureHumanVerificationUnavailable` | The security check is not available right now. Please try again in a moment. | Die sekuriteitskontrole is tans nie beskikbaar nie. Probeer oor 'n oomblik weer. | Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwesikhashana. |
| `failureHumanVerificationUnavailableSeconds` | The security check is not available right now. Please try again in {seconds} seconds. | Die sekuriteitskontrole is tans nie beskikbaar nie. Probeer oor {seconds} sekondes weer. | Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwemizuzwana engu-{seconds}. |
| `failureHumanVerificationUnavailableMinutes` | The security check is not available right now. Please try again in {minutes} minutes. | Die sekuriteitskontrole is tans nie beskikbaar nie. Probeer oor {minutes} minute weer. | Ukuhlolwa kokuphepha akutholakali manje. Sicela uzame futhi ngemva kwemizuzu engu-{minutes}. |
| `failureReauthRequired` | That code did not work. Check it and try again. | Daardie kode het nie gewerk nie. Kontroleer dit en probeer weer. | Leyo khodi ayisebenzanga. Yihlole bese uyazama futhi. |
| `failureSmsUnavailable` | We could not send the SMS. Please try again in a moment. | Ons kon nie die SMS stuur nie. Probeer oor 'n oomblik weer. | Asikwazanga ukuthumela i-SMS. Sicela uzame futhi ngemva kwesikhashana. |
| `failureConsentVersionOutdated` | The terms were updated. Please review and accept the latest version. | Die bepalings is opgedateer. Hersien en aanvaar asseblief die nuutste weergawe. | Imigomo ibuyekeziwe. Sicela ubuyekeze futhi wamukele inguqulo yamuva. |
| `failureSubscriberNotFound` | We could not find a service account for you with this provider. | Ons kon nie 'n diensrekening vir jou by hierdie verskaffer vind nie. | Asikwazanga ukuthola i-akhawunti yesevisi yakho kulo muntu onikezayo. |
| `failureActiveServiceExists` | You still have an active service. Cancel it first, or contact your provider. | Jy het nog 'n aktiewe diens. Kanselleer dit eers, of kontak jou verskaffer. | Usenayo isevisi esebenzayo. Qala ngokuyiklomelisa, noma uxhumane nomuntu onikezayo. |
| `failureDeleteContactSupport` | We cannot send a code to this account. Contact support to delete your account. | Ons kan nie 'n kode na hierdie rekening stuur nie. Kontak ondersteuning om jou rekening uit te vee. | Asikwazi ukuthumela ikhodi kule akhawunti. Xhumana nosekelo ukuze isuswe i-akhawunti yakho. |
| `accountDeleteSendCode` | Send me a code | Stuur vir my 'n kode | Ngithumelele ikhodi |
| `accountDeleteCodeTitle` | Enter the code we sent you | Voer die kode in wat ons vir jou gestuur het | Faka ikhodi esikuthumelele yona |
| `accountDeleteCodeBody` | For your safety we sent a 6-digit code by SMS to the number on your account. Enter it to delete your account and all your data. This cannot be undone. | Vir jou veiligheid het ons 'n 6-syfer-kode per SMS gestuur na die nommer op jou rekening. Voer dit in om jou rekening en al jou data uit te vee. Dit kan nie ongedaan gemaak word nie. | Ukuze uphephe sithumele ikhodi enezinombolo ezi-6 nge-SMS enombolweni ku-akhawunti yakho. Yifake ukuze usule i-akhawunti yakho nayo yonke idatha. Lokhu akunakuhlehliswa. |
| `accountDeleteClose` | Close | Maak toe | Vala |
| `humanCheckTitle` | Quick check: confirm you are a person | Vinnige kontrole: bevestig dat jy 'n mens is | Ukuhlola okusheshayo: qinisekisa ukuthi ungumuntu |
| `humanCheckBody` | This keeps automated sign-ups out. It usually takes a second. | Dit hou outomatiese aanmeldings uit. Dit neem gewoonlik net 'n sekonde. | Lokhu kugcina ukubhaliswa okuzenzakalelayo kuphume. Ngokuvamile kuthatha isekhondi kuphela. |
| `humanCheckLoading` | Loading the check… | Laai tans die kontrole… | Iyalayisha ukuhlola… |
| `humanCheckChallenge` | Please complete the check below. | Voltooi asseblief die kontrole hieronder. | Sicela ugcwalise ukuhlola ngezansi. |
| `humanCheckFailedNetwork` | We could not load the check. Check your connection and try again. | Ons kon nie die kontrole laai nie. Kontroleer jou verbinding en probeer weer. | Asikwazanga ukulayisha ukuhlola. Hlola uxhumo lwakho bese uyazama futhi. |
| `humanCheckFailedWidget` | The check did not work this time. Please try again. | Die kontrole het hierdie keer nie gewerk nie. Probeer asseblief weer. | Ukuhlola akusebenzanga kulokhu. Sicela uzame futhi. |
| `humanCheckFailedTimeout` | The check took too long. Please try again. | Die kontrole het te lank gevat. Probeer asseblief weer. | Ukuhlola kuthathe isikhathi eside kakhulu. Sicela uzame futhi. |
| `humanCheckRetry` | Try again | Probeer weer | Zama futhi |
| `humanCheckCancel` | Cancel | Kanselleer | Khansela |
| `humanCheckWidgetLabel` | Security check | Sekuriteitskontrole | Ukuhlola ukuphepha |
| `humanCheckHelp` | Still stuck? Cancel and sign in on the website, or contact support. | Nog vas? Kanselleer en meld aan op die webwerf, of kontak ondersteuning. | Usabambekile? Khansela bese ungena kuwebhusayithi, noma uxhumane nosekelo. |
