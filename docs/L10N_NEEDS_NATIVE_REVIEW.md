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

Typed problem codes added 2026-10-29 (contract re-sync, audit row 15). Same review rule: machine-quality drafts, native review before release.

| Key | English | Afrikaans | isiZulu |
|---|---|---|---|
| `failureFeatureDisabled` | This is not available from your provider. | Dit is nie by jou verskaffer beskikbaar nie. | Lokhu akutholakali kumuntu onikezayo. |
| `failureOrderNotCancellable` | This order can no longer be cancelled. | Hierdie bestelling kan nie meer gekanselleer word nie. | I-oda leli alisakwazi ukukhanselwa. |
| `failureOrderCancelled` | This order was cancelled. | Hierdie bestelling is gekanselleer. | I-oda leli likhanseliwe. |
| `failureSupportUnavailable` | Support messages are not available right now. Please try again later. | Ondersteuningsboodskappe is nou nie beskikbaar nie. Probeer asseblief later weer. | Imiyalezo yosizo ayitholakali okwamanje. Sicela uzame futhi kamuva. |
| `failureSupportContactNotConfigured` | Your provider has not set up support messages yet. | Jou verskaffer het nog nie ondersteuningsboodskappe opgestel nie. | Umuntu onikezayo akakawumisi umyalezo wosizo. |
| `failureInvalidMessage` | Check your message and try again. | Kontroleer jou boodskap en probeer weer. | Hlola umyalezo wakho bese uzame futhi. |
| `failureInvalidContact` | Check your contact details and try again. | Kontroleer jou kontakbesonderhede en probeer weer. | Hlola imininingwane yakho yokuxhumana bese uzame futhi. |
| `failureInvoiceNotPayable` | This invoice can no longer be paid. | Hierdie faktuur kan nie meer betaal word nie. | I-invoyisi le ayisakwazi ukukhokhwa. |
| `failureCustomerLinkRequired` | Your account is not linked to your provider yet. Contact your provider. | Jou rekening is nog nie aan jou verskaffer gekoppel nie. Kontak jou verskaffer. | I-akhawunti yakho ayikaxhunyaniswa nomuntu onikezayo. Xhumana nomuntu onikezayo. |
| `failureSubscriberProfileInvalid` | Update your contact details before signing up. | Werk jou kontakbesonderhede op voordat jy inteken. | Buyekeza imininingwane yakho yokuxhumana ngaphambi kokubhalisa. |
| `failureNoActiveEntitlement` | You need an active pass to get online. | Jy het 'n aktiewe pas nodig om aanlyn te kom. | Udinga ipasi elisebenzayo ukuze uxhume ku-inthanethi. |
| `failureMacInvalid` | We could not identify this device. Connect from the Wi-Fi login page instead. | Ons kon nie hierdie toestel identifiseer nie. Koppel eerder vanaf die Wi-Fi-aanmeldbladsy. | Asikwazanga ukuhlonza le divayisi. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni. |
| `failureNasUnavailable` | This hotspot is not available right now. Try another one. | Hierdie warmkol is nou nie beskikbaar nie. Probeer 'n ander een. | Le hotspot ayitholakali okwamanje. Zama enye. |
| `failureLoginUrlInvalid` | This hotspot login could not be opened. Connect from the Wi-Fi login page instead. | Hierdie warmkol-aanmelding kon nie oopgemaak word nie. Koppel eerder vanaf die Wi-Fi-aanmeldbladsy. | Ukungena kwale hotspot akukwazanga ukuvulwa. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni. |
| `failureControllerNotSupported` | One-tap login is not supported at this hotspot. Connect from the Wi-Fi login page instead. | Eenklik-aanmelding word nie by hierdie warmkol ondersteun nie. Koppel eerder vanaf die Wi-Fi-aanmeldbladsy. | Ukungena ngokuthinta kanye akuxhaswa kule hotspot. Xhuma ngekhasi lokungena le-Wi-Fi esikhundleni. |
| `failurePlanUnavailable` | This plan is no longer available. | Hierdie pakket is nie meer beskikbaar nie. | Lolu hlelo alisatholakali. |
| `failureServiceState` | This service can't be changed right now. | Hierdie diens kan nou nie verander word nie. | Le sevisi ayikwazi ukushintshwa okwamanje. |
| `hotspotsStatusMaintenance` | Under maintenance | Onder instandhouding | Ilungiswa |
| `hotspotsEmpty` | No hotspots are listed yet. Check back soon. | Daar is nog geen warmkolle gelys nie. Kyk gou weer. | Awekho ama-hotspot abhaliwe okwamanje. Buyela maduze. |
| `orderCancelAction` | Cancel order | Kanselleer bestelling | Khansela i-oda |
| `orderCancelConfirmTitle` | Cancel this order? | Kanselleer hierdie bestelling? | Khansela leli oda? |
| `orderCancelConfirmBody` | This order will be closed. You can place a new order any time. | Hierdie bestelling sal gesluit word. Jy kan enige tyd 'n nuwe bestelling plaas. | Leli oda lizovalwa. Ungenza i-oda elisha noma nini. |
| `orderCancelKeep` | Keep order | Hou bestelling | Gcina i-oda |

Support message form (2026-10-30, `POST /v1/support/messages`). Machine-quality drafts, native review before release.

| Key | English | Afrikaans | isiZulu |
|---|---|---|---|
| `supportComposeTitle` | Message support | Stuur boodskap aan ondersteuning | Thumela umlayezo osizweni |
| `supportTopicLabel` | Topic | Onderwerp | Isihloko |
| `supportTopicConnecting` | Connecting to Wi-Fi | Koppel aan Wi-Fi | Ukuxhuma ku-Wi-Fi |
| `supportTopicPayment` | Payment | Betaling | Inkokhelo |
| `supportTopicPass` | My pass | My pas | Ipasi lami |
| `supportTopicAccount` | My account | My rekening | I-akhawunti yami |
| `supportTopicOther` | Other | Ander | Okunye |
| `supportContactKindEmail` | Email | E-pos | I-imeyili |
| `supportContactKindPhone` | Mobile | Selfoon | Iselula |
| `supportContactEmailLabel` | Your email address | Jou e-posadres | Ikheli lakho le-imeyili |
| `supportContactPhoneLabel` | Your mobile number | Jou selfoonnommer | Inombolo yakho yeselula |
| `supportMessageLabel` | Your message | Jou boodskap | Umlayezo wakho |
| `supportOrderRefLabel` | Order reference (optional) | Bestellingverwysing (opsioneel) | Inkomba ye-oda (akuphoqelekile) |
| `supportSendMessage` | Send message | Stuur boodskap | Thumela umlayezo |
| `supportSentTitle` | Message sent | Boodskap gestuur | Umlayezo uthunyelwe |
| `supportSentBody` | We have your message. Quote this reference if you contact support again. | Ons het jou boodskap. Noem hierdie verwysing as jy weer met ondersteuning skakel. | Silutholile umlayezo wakho. Sebenzisa le nkomba uma uphinda uxhumana nosizo. |
| `supportSentReference` | Reference: {reference} | Verwysing: {reference} | Inkomba: {reference} |
| `supportDone` | Done | Klaar | Kwenziwe |
| `supportIssueMessageTooShort` | Write at least 10 characters. | Skryf ten minste 10 karakters. | Bhala okungenani izinhlamvu eziyi-10. |
| `supportIssueMessageTooLong` | Keep your message under 2000 characters. | Hou jou boodskap onder 2000 karakters. | Gcina umlayezo wakho ungaphansi kwezinhlamvu ezi-2000. |
| `supportIssueOrderRef` | An order reference has letters, numbers and dashes only (4 to 40). | 'n Bestellingverwysing het net letters, syfers en koppeltekens (4 tot 40). | Inkomba ye-oda inamagama, izinombolo namadashi kuphela (4 kuya ku-40). |
| `supportEmailInstead` | Email us instead | Stuur eerder vir ons 'n e-pos | Sithumelele i-imeyili esikhundleni |

Subscriber services (S3, 2026-10-30). Machine-quality drafts, native review before release.

| Key | English | Afrikaans | isiZulu |
|---|---|---|---|
| `servicesHomeInternetHeading` | Home internet | Internet yasekhaya | Iintanethi yasekhaya |
| `servicesTitle` | My services | My dienste | Amasevisi ami |
| `servicesEmpty` | You have no home internet service yet | Jy het nog nie 'n tuisinternetdiens nie | Awunayo isevisi yeintanethi yasekhaya okwamanje |
| `servicesPastTitle` | Past services | Vorige dienste | Amasevisi adlule |
| `serviceDetailTitle` | Service details | Diensbesonderhede | Imininingwane yesevisi |
| `serviceStatusPending` | Starting | Begin tans | Iyaqala |
| `serviceStatusActive` | Active | Aktief | Iyasebenza |
| `serviceStatusSuspended` | Suspended | Opgeskort | Imisiwe |
| `serviceStatusCancelled` | Ended | Beëindig | Iphelile |
| `serviceKindHotspot` | Home hotspot | Tuis-warmkol | I-hotspot yasekhaya |
| `serviceKindFixedWireless` | Fixed wireless | Vaste draadloos | I-fixed wireless |
| `servicePricePerMonth` | {price} a month | {price} per maand | {price} ngenyanga |
| `serviceSpeeds` | Down {down} Mbps, up {up} Mbps | Af {down} Mbps, op {up} Mbps | Phansi {down} Mbps, phezulu {up} Mbps |
| `serviceNumber` | Service {number} | Diens {number} | Isevisi {number} |
| `servicePaidUntil` | Paid until {date} | Betaal tot {date} | Ikhokhelwe kuze kube yilo {date} |
| `serviceEndsOn` | Ends on {date} | Eindig op {date} | Iphela ngo-{date} |
| `serviceEndedOn` | Ended on {date} | Beëindig op {date} | Iphele ngo-{date} |
| `serviceCancelScheduledTitle` | Cancellation scheduled | Kansellasie geskeduleer | Ukukhansela kuhlelwe |
| `servicePlanChangeOn` | Plan change to {plan} on {date} | Planverandering na {plan} op {date} | Ukushintsha uhlelo kuye ku-{plan} ngo-{date} |
| `servicePlanChangeScheduled` | A plan change is scheduled for {date} | 'n Planverandering is geskeduleer vir {date} | Ukushintsha uhlelo kuhlelwe ngo-{date} |
| `serviceFactPlan` | Plan | Plan | Uhlelo |
| `serviceFactType` | Type | Tipe | Uhlobo |
| `serviceFactPrice` | Price | Prys | Intengo |
| `serviceFactSpeed` | Speed | Spoed | Isivinini |
| `serviceFactNumber` | Service number | Dienstnommer | Inombolo yesevisi |
| `serviceFactPaidThrough` | Paid until | Betaal tot | Ikhokhelwe kuze kube |
| `serviceBannerFirstInvoiceUnpaid` | Pay your first invoice to start | Betaal jou eerste faktuur om te begin | Khokha i-invoyisi yakho yokuqala ukuze uqale |
| `serviceBannerKycRequired` | We need to check your ID | Ons moet jou ID nagaan | Sidinga ukuhlola i-ID yakho |
| `serviceBannerAwaitingInstallation` | Waiting for installation by your provider | Wag vir installasie deur jou verskaffer | Kulindwe ukufakwa umhlinzeki wakho |
| `serviceBannerCustomerLinkRequired` | Your account is not linked to your provider yet. Contact your provider. | Jou rekening is nog nie aan jou verskaffer gekoppel nie. Kontak jou verskaffer. | I-akhawunti yakho ayixhunyiwe nomhlinzeki wakho. Xhumana nomhlinzeki wakho. |
| `serviceBannerContractRequired` | Your service contract is not signed yet. Contact your provider. | Jou dienskontrak is nog nie geteken nie. Kontak jou verskaffer. | Inkontileka yakho yesevisi ayisayinwanga. Xhumana nomhlinzeki wakho. |
| `serviceBannerActivating` | Activating, this can take a few minutes. Pull to refresh. | Aktiveer tans, dit kan 'n paar minute neem. Trek om te herlaai. | Iyasebenza, lokhu kungathatha amaminithi ambalwa. Donsa ukuvuselela. |
| `serviceBannerProviderSettingUp` | Your provider is setting this up | Jou verskaffer rig dit tans op | Umhlinzeki wakho uyakumisa |
| `serviceBannerSuspendedNonPayment` | Pay your open invoice to restore service | Betaal jou oop faktuur om diens te herstel | Khokha i-invoyisi yakho evuliwe ukuze isevisi ibuyiselwe |
| `serviceBannerSuspendedKyc` | We need to check your ID before service can resume | Ons moet jou ID nagaan voor diens kan hervat | Sidinga ukuhlola i-ID yakho ngaphambi kokuthi isevisi iqhubeke |
| `serviceBannerSuspendedProvider` | Paused by your provider. Contact support. | Deur jou verskaffer onderbreek. Kontak ondersteuning. | Imiswe umhlinzeki wakho. Xhumana nosizo. |
| `serviceActionViewInvoices` | View invoices | Sien fakture | Buka ama-invoyisi |
| `serviceActionIdCheck` | Start ID check | Begin ID-kontrole | Qala ukuhlola i-ID |
