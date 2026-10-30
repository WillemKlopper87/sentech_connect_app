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

Subscriber invoices (S2, 2026-10-30). Machine-quality drafts, native review before release.

| Key | English | Afrikaans | isiZulu |
|---|---|---|---|
| `invoicesTitle` | Invoices | Fakture | Odinga |
| `invoicesEmptyTitle` | No invoices yet | Nog geen fakture nie | Awukabi nama-invoyisi |
| `invoicesEmptyBody` | Invoices for your home internet service will show here. | Fakture vir jou tuisinternetdiens sal hier verskyn. | Odinga bensizakalo yakho ye-inthanethi yasekhaya buzovela lapha. |
| `invoicesOpenSection` | To pay | Om te betaal | Okufanele kukhokhwe |
| `invoicesEarlierSection` | Earlier invoices | Vroeëre fakture | Odinga bangaphambilini |
| `invoiceStatusOpen` | Due | Verskuldig | Kufanele kukhokhwe |
| `invoiceStatusPaid` | Paid | Betaal | Kukhokhiwe |
| `invoiceStatusVoid` | Cancelled | Gekanselleer | Kukhanselwe |
| `invoiceStatusWrittenOff` | Written off | Afgeskryf | Kushiyiwe |
| `invoiceKindInitial` | First invoice | Eerste faktuur | I-invoyisi yokuqala |
| `invoiceKindRecurring` | Monthly invoice | Maandelikse faktuur | I-invoyisi yenyanga |
| `invoiceKindProration` | Plan change | Planverandering | Ushintsho lohlelo |
| `invoiceKindReactivation` | Reactivation | Heraktivering | Ukuvuselelwa |
| `invoiceKindAdjustment` | Adjustment | Aanpassing | Ukulungiswa |
| `invoiceKindOther` | Invoice | Faktuur | I-invoyisi |
| `invoiceDueOn` | Due {date} | Verskuldig {date} | Kufanele kukhokhwe ngo-{date} |
| `invoiceIssuedOn` | Issued {date} | Uitgereik {date} | Kukhishwe ngo-{date} |
| `invoicePaidOn` | Paid {date} | Betaal {date} | Kukhokhwe ngo-{date} |
| `invoiceDetailTitle` | Invoice | Faktuur | I-invoyisi |
| `invoicePeriod` | Period: {start} to {end} | Tydperk: {start} tot {end} | Isikhathi: {start} kuya ku-{end} |
| `invoiceLinesHeading` | What you are paying for | Waarvoor jy betaal | Okukhokhelayo |
| `invoiceLineQuantity` | {quantity} x {price} | {quantity} x {price} | {quantity} x {price} |
| `invoiceTotal` | Total | Totaal | Isamba |
| `invoiceIncludesVat` | Includes VAT of {amount} | Sluit BTW van {amount} in | Kubandakanya i-VAT ye-{amount} |
| `invoiceAmountPaid` | Paid so far | Tot dusver betaal | Okukhokhiwe kuze kube manje |
| `invoicePartPaid` | Part of this invoice is already paid. Contact support to settle the rest. | Deel van hierdie faktuur is reeds betaal. Kontak ondersteuning om die res te vereffen. | Ingxenye yale invoyisi isikhokhiwe. Xhumana nosizo ukuze uphothule okusele. |
| `invoiceVoidNote` | This invoice was cancelled. Nothing is due. | Hierdie faktuur is gekanselleer. Niks is verskuldig nie. | Le nvoyisi ikhanseliwe. Akukho okufanele kukhokhwe. |
| `invoiceWrittenOffNote` | This invoice was written off. Nothing is due. | Hierdie faktuur is afgeskryf. Niks is verskuldig nie. | Le nvoyisi ishiyiwe. Akukho okufanele kukhokhwe. |
| `invoicePayNow` | Pay {amount} | Betaal {amount} | Khokha {amount} |
| `invoicePayOnSecurePage` | You pay on your payment provider's secure page. | Jy betaal op jou betalingsverskaffer se veilige bladsy. | Ukhokha ekhasini eligcinekile lomhlinzeki wenkokhelo yakho. |
| `invoiceConfirming` | Confirming your payment. This can take a moment. | Bevestig tans jou betaling. Dit kan 'n oomblik neem. | Siqinisekisa inkokhelo yakho. Lokhu kungathatha isikhashana. |
| `invoiceStillPending` | We have not heard back from the payment provider yet. If you paid, this invoice will update soon. | Ons het nog nie van die betalingsverskaffer gehoor nie. As jy betaal het, sal hierdie faktuur binnekort opdateer. | Asikezwa lutho kumhlinzeki wenkokhelo. Uma usukhokhile, le nvoyisi izobuyekezwa maduze. |
| `invoicePaidTitle` | Payment received | Betaling ontvang | Inkokhelo emukelwe |
| `invoicePaidThanks` | Thank you. This invoice is paid. | Dankie. Hierdie faktuur is betaal. | Siyabonga. Le nvoyisi ikhokhiwe. |
| `invoicePaidKyc` | We need to check your ID before your service starts. | Ons moet jou ID nagaan voordat jou diens begin. | Kudingeka sihlole i-ID yakho ngaphambi kokuthi isevisi yakho iqale. |
| `invoicePaidInstallation` | Waiting for installation by your provider. | Wag vir installasie deur jou verskaffer. | Silindele ukufakwa ngumhlinzeki wakho. |
| `invoicePaidContactProvider` | Your service cannot start yet. Contact your provider. | Jou diens kan nog nie begin nie. Kontak jou verskaffer. | Isevisi yakho ayikwazi ukuqala okwamanje. Xhumana nomhlinzeki wakho. |
| `invoicePaidActivating` | Your service is starting. This can take a few minutes. Pull to refresh. | Jou diens begin tans. Dit kan 'n paar minute neem. Trek om te herlaai. | Isevisi yakho iyaqala. Lokhu kungathatha amaminithi ambalwa. Donsa ukuze uvuselele. |
| `invoicePaidSettingUp` | Your provider is setting up your service. | Jou verskaffer rig jou diens op. | Umhlinzeki wakho ulungisa isevisi yakho. |
| `invoiceCollectionExternal` | Your provider collects payment for this invoice directly. | Jou verskaffer vorder betaling vir hierdie faktuur self in. | Umhlinzeki wakho uqoqa inkokhelo yale nvoyisi ngokwakhe. |
| `invoiceBackToInvoices` | Back to invoices | Terug na fakture | Buyela kuma-invoyisi |
| `failureAccountProblem` | There is a problem with your account. Contact your provider. | Daar is 'n probleem met jou rekening. Kontak jou verskaffer. | Kunenkinga ne-akhawunti yakho. Xhumana nomhlinzeki wakho. |
ID check (slice S4, 2026-10-30). Same rule: machine-quality drafts, native review before release. Placeholders `{date}`, `{type}`, `{last4}` must stay.

| Key | English | Afrikaans (draft) | isiZulu (draft) |
|---|---|---|---|
| `kycTitle` | ID check | ID-kontrole | Ukuhlolwa kwe-ID |
| `kycRowSubtitle` | Needed for some monthly plans | Nodig vir sommige maandelikse planne | Kudingeka kwezinye izinhlelo zenyanga |
| `kycNoAccount` | You do not have a home internet account yet, so there is no ID check to do. | Jy het nog nie 'n tuisinternet-rekening nie, so daar is nog geen ID-kontrole om te doen nie. | Awunayo i-akhawunti ye-inthanethi yasekhaya okwamanje, ngakho akukho ukuhlolwa kwe-ID okufanele kwenziwe. |
| `kycNoneTitle` | We need to check your ID | Ons moet jou ID nagaan | Sidinga ukuhlola i-ID yakho |
| `kycNoneBody` | Some monthly plans need your ID checked before they start. Send your ID details and one photo of your ID document. Your provider checks them by hand. | Sommige maandelikse planne vereis dat jou ID eers nagegaan word. Stuur jou ID-besonderhede en een foto van jou ID-dokument. Jou verskaffer gaan dit met die hand na. | Ezinye izinhlelo zenyanga zidinga ukuthi i-ID yakho ihlolwe ngaphambi kokuqala. Thumela imininingwane ye-ID yakho nesithombe esisodwa sedokhumenti ye-ID. Umhlinzeki wakho uyihlola ngesandla. |
| `kycStart` | Start ID check | Begin ID-kontrole | Qala ukuhlolwa kwe-ID |
| `kycPendingTitle` | We are checking your ID | Ons gaan jou ID na | Siyayihlola i-ID yakho |
| `kycPendingBody` | Your provider is checking what you sent. We will notify you when there is a decision. | Jou verskaffer gaan na wat jy gestuur het. Ons sal jou in kennis stel sodra daar 'n besluit is. | Umhlinzeki wakho uyahlola lokho okuthumele. Sizokwazisa uma sekunesinqumo. |
| `kycVerifiedTitle` | Your ID is verified | Jou ID is geverifieer | I-ID yakho iqinisekisiwe |
| `kycVerifiedBody` | Nothing more to do. Your ID check is done. | Niks meer om te doen nie. Jou ID-kontrole is klaar. | Akukho okunye okufanele ukwenze. Ukuhlolwa kwe-ID yakho kuqediwe. |
| `kycVerifiedOn` | Verified on {date} | Geverifieer op {date} | Iqinisekiswe ngomhla ka-{date} |
| `kycSentOn` | Sent on {date} | Gestuur op {date} | Kuthunyelwe ngomhla ka-{date} |
| `kycRejectedTitle` | We could not accept your ID check | Ons kon nie jou ID-kontrole aanvaar nie | Asikwazanga ukwamukela ukuhlolwa kwe-ID yakho |
| `kycRejectedBody` | Please check your details and send them again. Your provider can tell you more. | Kontroleer asseblief jou besonderhede en stuur dit weer. Jou verskaffer kan jou meer vertel. | Sicela uhlole imininingwane yakho bese uyithumela futhi. Umhlinzeki wakho angakutshela okwengeziwe. |
| `kycSubmitAgain` | Send again | Stuur weer | Thumela futhi |
| `kycIdTypeSaId` | South African ID number | Suid-Afrikaanse ID-nommer | Inombolo ye-ID yaseNingizimu Afrika |
| `kycIdTypePassport` | Passport number | Paspoortnommer | Inombolo yephasipoti |
| `kycIdTypeCompanyReg` | Company registration number | Maatskappyregistrasienommer | Inombolo yokubhaliswa kwenkampani |
| `kycEndingIn` | {type} ending in {last4} | {type} wat eindig op {last4} | {type} equkela ku-{last4} |
| `kycFormIntro` | Enter the details exactly as they appear on your ID document. | Voer die besonderhede presies in soos dit op jou ID-dokument verskyn. | Faka imininingwane ngqo njengoba ivela kudokhumenti yakho ye-ID. |
| `kycFieldIdType` | Type of ID | Tipe ID | Uhlobo lwe-ID |
| `kycHintSaId` | 13 digits | 13 syfers | Izinombolo eziyi-13 |
| `kycHintPassport` | 6 to 12 letters or digits | 6 tot 12 letters of syfers | Amalungu angu-6 kuya ku-12 noma izinombolo |
| `kycHintCompanyReg` | Format 1234/123456/12 | Formaat 1234/123456/12 | Ifomethi 1234/123456/12 |
| `kycFieldAddress` | Home address | Huisadres | Ikheli lasekhaya |
| `kycFieldAddressHint` | Street, suburb, city and postal code | Straat, voorstad, stad en poskode | Isitaladi, indawo, idolobha nekhodi yeposi |
| `kycPhotoTitle` | Photo of your ID document | Foto van jou ID-dokument | Isithombe sedokhumenti yakho ye-ID |
| `kycPhotoHelp` | Take a clear photo in good light, with all four corners and all the text readable. | Neem 'n duidelike foto in goeie lig, met al vier hoeke en al die teks leesbaar. | Thatha isithombe esicacile ekukhanyeni okuhle, onxande abane bonke nombhalo wonke ufundeka. |
| `kycTakePhoto` | Take a photo | Neem 'n foto | Thatha isithombe |
| `kycChoosePhoto` | Choose from gallery | Kies uit galery | Khetha kugalari |
| `kycReplacePhoto` | Replace photo | Vervang foto | Shintsha isithombe |
| `kycRemovePhoto` | Remove photo | Verwyder foto | Susa isithombe |
| `kycPhotoPreview` | Preview of your ID document photo | Voorskou van jou ID-dokumentfoto | Ukubuka kuqala isithombe sedokhumenti yakho ye-ID |
| `kycPhotoPreparing` | Preparing your photo… | Berei tans jou foto voor… | Silungisa isithombe sakho… |
| `kycPhotoDenied` | We cannot open the camera or your photos. Choose another way, or allow access in Settings. | Ons kan nie die kamera of jou foto's oopmaak nie. Kies 'n ander manier, of laat toegang toe in Instellings. | Asikwazi ukuvula ikhamera noma izithombe zakho. Khetha enye indlela, noma uvumele ukufinyelela Kumasethingi. |
| `kycOpenSettings` | Open Settings | Maak Instellings oop | Vula Amasethingi |
| `kycPhotoUnreadable` | We could not read that photo. Choose another one. | Ons kon nie daardie foto lees nie. Kies 'n ander een. | Asikwazanga ukufunda lesi sithombe. Khetha esinye. |
| `kycPhotoTooLarge` | That photo is too large to send. Choose a smaller one. | Daardie foto is te groot om te stuur. Kies 'n kleiner een. | Lesi sithombe sikhulu kakhulu ukuthi singathunyelwa. Khetha esincane. |
| `kycPhotoFailed` | We could not get a photo. Please try again. | Ons kon nie 'n foto kry nie. Probeer asseblief weer. | Asikwazanga ukuthola isithombe. Sicela uzame futhi. |
| `kycPhotoRequired` | Add a photo of your ID document. | Voeg 'n foto van jou ID-dokument by. | Engeza isithombe sedokhumenti yakho ye-ID. |
| `kycConsentLabel` | I agree that my provider may use these details and this photo to check my identity, as set out in the privacy notice. | Ek stem in dat my verskaffer hierdie besonderhede en foto mag gebruik om my identiteit na te gaan, soos in die privaatheidskennisgewing uiteengesit. | Ngiyavuma ukuthi umhlinzeki wami angasebenzisa le mininingwane nesi sithombe ukuhlola ubunikazi bami, njengoba kuchaziwe esitatimendeni sobumfihlo. |
| `kycConsentRequired` | Please agree to continue. | Stem asseblief in om voort te gaan. | Sicela uvume ukuze uqhubeke. |
| `kycPrivacyLink` | Read the privacy notice | Lees die privaatheidskennisgewing | Funda isitatimende sobumfihlo |
| `kycSendNote` | The app does not keep your ID number or photo after you send them. | Die toepassing hou nie jou ID-nommer of foto nadat jy dit gestuur het nie. | Uhlelo lokusebenza alugcini inombolo ye-ID yakho noma isithombe ngemva kokuthi usithumele. |
| `kycSubmit` | Send for checking | Stuur vir nagaan | Thumela ukuze kuhlolwe |
| `kycSubmitting` | Sending… | Stuur tans… | Iyathumela… |
| `kycSuccessTitle` | Your ID check is sent | Jou ID-kontrole is gestuur | Ukuhlolwa kwe-ID yakho kuthunyelwe |
| `kycSuccessBody` | Your provider will check it. We will notify you when there is a decision. | Jou verskaffer sal dit nagaan. Ons sal jou in kennis stel sodra daar 'n besluit is. | Umhlinzeki wakho uzokuhlola. Sizokwazisa uma sekunesinqumo. |
| `kycSuccessDone` | View status | Sien status | Buka isimo |
| `failureKycInvalidId` | Check your ID number. | Kontroleer jou ID-nommer. | Hlola inombolo yakho ye-ID. |
| `failureKycInvalidAddress` | Check your address. | Kontroleer jou adres. | Hlola ikheli lakho. |
| `failureKycDocumentRejected` | Use a clear JPEG or PNG photo under 5 MB. | Gebruik 'n duidelike JPEG- of PNG-foto onder 5 MB. | Sebenzisa isithombe esicacile se-JPEG noma se-PNG esingaphansi kuka-5 MB. |
| `failureKycUploadFailed` | We could not upload your document. Try again. | Ons kon nie jou dokument oplaai nie. Probeer weer. | Asikwazanga ukulayisha idokhumenti yakho. Zama futhi. |
| `failureKycRequired` | You need an ID check first. | Jy moet eers 'n ID-kontrole hê. | Kudingeka ukuthi uqale ngokuhlolwa kwe-ID. |
| `homeSubscriberHeading` | Your home internet | Jou tuisinternet | I-inthanethi yakho yasekhaya |
| `homeInvoiceDue` | {amount} due {date} | {amount} verskuldig op {date} | {amount} kufanele kukhokhwe ngo-{date} |
| `homeInvoicePay` | Pay | Betaal | Khokha |
| `homeInvoicesViewAll` | View all invoices | Sien alle fakture | Buka bonke odinga |
| `serviceChangePlanAction` | Change plan | Verander plan | Shintsha uhlelo |
| `serviceChangePlanBlockedCancelling` | Not available while cancellation is scheduled. | Nie beskikbaar terwyl kansellasie geskeduleer is nie. | Akutholakali ngenkathi ukukhansela kuhleliwe. |
| `serviceChangePlanBlockedInactive` | Available once your service is active. | Beskikbaar sodra jou diens aktief is. | Kutholakala uma isevisi yakho isisebenza. |
| `serviceCancelAction` | Cancel service | Kanselleer diens | Khansela isevisi |
| `serviceCancelPendingContact` | Contact support to cancel a service that has not started. | Kontak ondersteuning om 'n diens wat nog nie begin het nie te kanselleer. | Xhumana nosizo ukuze ukhansele isevisi engakaqali. |
| `serviceCancelNoUndo` | A scheduled cancellation cannot be undone in the app. Contact your provider if you changed your mind. | 'n Geskeduleerde kansellasie kan nie in die toepassing ontdoen word nie. Kontak jou verskaffer as jy van plan verander het. | Ukukhansela okuhleliwe akukwazi ukuhlehliswa kuhlelo lokusebenza. Xhumana nomhlinzeki wakho uma ushintshe umqondo. |
| `changePlanTitle` | Change plan | Verander plan | Shintsha uhlelo |
| `changePlanCurrent` | Your plan: {plan} | Jou plan: {plan} | Uhlelo lwakho: {plan} |
| `changePlanChoose` | Choose a new plan | Kies 'n nuwe plan | Khetha uhlelo olusha |
| `changePlanEmpty` | There are no other plans you can switch to right now. | Daar is tans geen ander planne waarna jy kan oorskakel nie. | Azikho ezinye izinhlelo ongashintshela kuzo njengamanje. |
| `changePlanIdCheckNeeded` | ID check needed | ID-kontrole nodig | Kudingeka ukuhlolwa kwe-ID |
| `changeConfirmTitle` | Change to {plan}? | Verander na {plan}? | Shintshela ku-{plan}? |
| `changeConfirmHigher` | Switches now. You will be invoiced the difference for the rest of this month. | Skakel nou oor. Jy sal gefaktureer word vir die verskil vir die res van hierdie maand. | Kushintsha manje. Uzothola i-invoyisi yomehluko wesikhathi esisele salokhu inyanga. |
| `changeConfirmLower` | Takes effect on {date}. Until then you keep your current plan. | Tree in werking op {date}. Tot dan hou jy jou huidige plan. | Kuqala ukusebenza ngo-{date}. Kuze kube yileso sikhathi ugcina uhlelo lwakho lwamanje. |
| `changeConfirmUnknown` | Your provider decides when this takes effect. | Jou verskaffer besluit wanneer dit in werking tree. | Umhlinzeki wakho unquma ukuthi kuqala nini ukusebenza. |
| `changeConfirmButton` | Change plan | Verander plan | Shintsha uhlelo |
| `changeSubmitting` | Changing plan… | Verander tans plan… | Iyashintsha uhlelo… |
| `changeResultAppliedTitle` | Plan changed | Plan verander | Uhlelo lushintshiwe |
| `changeResultAppliedBody` | You are now on {plan}. | Jy is nou op {plan}. | Manje usohlelweni lwe-{plan}. |
| `changeResultScheduledTitle` | Plan change scheduled | Planverandering geskeduleer | Ushintsho loluhlelo luhleliwe |
| `changeResultScheduledBody` | Scheduled for {date}. Until then you keep your current plan. | Geskeduleer vir {date}. Tot dan hou jy jou huidige plan. | Kuhlelelwe ngo-{date}. Kuze kube yileso sikhathi ugcina uhlelo lwakho lwamanje. |
| `changeResultViewInvoice` | View invoice | Sien faktuur | Buka i-invoyisi |
| `cancelDialogTitle` | Cancel this service? | Kanselleer hierdie diens? | Khansela le sevisi? |
| `cancelDialogBody` | Your service stays active until {date}. After that it stops and you will not be billed again. | Jou diens bly aktief tot {date}. Daarna stop dit en jy sal nie weer gefaktureer word nie. | Isevisi yakho ihlala isebenza kuze kube ngu-{date}. Ngemva kwalokho iyama futhi ngeke usatshaji futhi. |
| `cancelDialogNoUndo` | This cannot be undone in the app. | Dit kan nie in die toepassing ontdoen word nie. | Lokhu akukwazi ukuhlehliswa kuhlelo lokusebenza. |
| `cancelReasonLabel` | Why are you leaving? | Hoekom vertrek jy? | Kungani uhamba? |
| `cancelReasonMoving` | I am moving | Ek trek | Ngiyathuthuka |
| `cancelReasonExpensive` | Too expensive | Te duur | Kubiza kakhulu |
| `cancelReasonUnreliable` | Not reliable enough | Nie betroubaar genoeg nie | Akwethembeki ngokwanele |
| `cancelReasonOther` | Other | Ander | Okunye |
| `cancelReasonDetailLabel` | Tell us more (optional) | Vertel ons meer (opsioneel) | Sitshele okwengeziwe (akuphoqelekile) |
| `cancelReasonRequired` | Choose a reason. | Kies 'n rede. | Khetha isizathu. |
| `cancelKeep` | Keep service | Hou diens | Gcina isevisi |
| `cancelConfirm` | Cancel service | Kanselleer diens | Khansela isevisi |
| `cancelSubmitting` | Cancelling… | Kanselleer tans… | Iyakhansela… |
| `cancelDone` | Cancellation scheduled for {date} | Kansellasie geskeduleer vir {date} | Ukukhansela kuhlelelwe ngo-{date} |
| `failureCancellationScheduled` | This service is already set to end. | Hierdie diens is reeds gestel om te eindig. | Le sevisi isivele ihlelelwe ukuphela. |
| `failurePlanChangeBilled` | Your next period is already billed. Try again after it starts. | Jou volgende tydperk is reeds gefaktureer. Probeer weer nadat dit begin het. | Isikhathi sakho esilandelayo sesivele sitshajiwe. Zama futhi ngemva kokuthi siqale. |
| `failurePendingCancel` | Contact support to cancel a service that has not started. | Kontak ondersteuning om 'n diens wat nog nie begin het nie te kanselleer. | Xhumana nosizo ukuze ukhansele isevisi engakaqali. |

Plans and signup (slice S5, 2026-10-30). Machine-quality drafts, native review before release. Placeholders `{price}`, `{count}`, `{amount}`, `{down}`, `{up}`, `{seconds}`, `{number}`, `{date}` and the plural form of `planDevices` must stay.

| Key | English | Afrikaans | isiZulu |
|---|---|---|---|
| `plansTitle` | Monthly plans | Maandelikse pakkette | Amaphakheji ngenyanga |
| `plansShopCardSubtitle` | Home internet for your household, billed monthly | Tuisinternet vir jou huishouding, maandeliks gefaktureer | I-inthanethi yasekhaya yomuzi wakho, ikhokhelwa ngenyanga |
| `plansEmpty` | No plans available right now | Geen pakkette is op die oomblik beskikbaar nie | Awekho amaphakheji atholakalayo okwamanje |
| `planIdCheckChip` | ID check needed | ID-kontrole nodig | Kudingeka ukuhlolwa kwe-ID |
| `planSetupFee` | Setup fee {price} | Opstelfooi {price} | Imali yokusetha {price} |
| `planDevices` | {count, plural, =1{1 device} other{Up to {count} devices}} | {count, plural, =1{1 toestel} other{Tot {count} toestelle}} | {count, plural, =1{idivayisi eyi-1} other{Kufika kumadivayisi angu-{count}}} |
| `planFairUse` | Fair use: {amount} a month | Billike gebruik: {amount} per maand | Ukusetshenziswa okufanele: {amount} ngenyanga |
| `planFairUseThrottle` | After that, speeds drop to {down} / {up} Mbps | Daarna daal spoed na {down} / {up} Mbps | Ngemva kwalokho, isivinini sehla siye ku-{down} / {up} Mbps |
| `planFairUseReduced` | After that, your speed is reduced | Daarna word jou spoed verlaag | Ngemva kwalokho, isivinini sakho siyehliswa |
| `planGigabytes` | {amount} GB | {amount} GB | {amount} GB |
| `planBurst` | Bursts up to {down} / {up} Mbps for {seconds} seconds | Kort uitbarstings tot {down} / {up} Mbps vir {seconds} sekondes | Ukuqhuma kuze kube ngu-{down} / {up} Mbps amasekhondi angu-{seconds} |
| `planDetailTitle` | Plan details | Pakketbesonderhede | Imininingwane yephakheji |
| `planChoose` | Choose this plan | Kies hierdie pakket | Khetha leli phakheji |
| `planBackToPlans` | Back to plans | Terug na pakkette | Buyela emaphakhejini |
| `servicesSeePlans` | See plans | Sien pakkette | Buka amaphakheji |
| `signupTitle` | Confirm sign-up | Bevestig inskrywing | Qinisekisa ukubhalisa |
| `signupFirstInvoiceNote` | Your first invoice covers the rest of this month, plus any setup fee. You see the exact amount before you pay. | Jou eerste faktuur dek die res van hierdie maand, plus enige opstelfooi. Jy sien die presiese bedrag voordat jy betaal. | Inxephezelo yakho yokuqala ihlanganisa inyanga esele, kanye nanoma iyiphi imali yokusetha. Uyabona inani eliphelele ngaphambi kokuba ukhokhe. |
| `signupAvailabilityNote` | Your provider confirms availability at your address. | Jou verskaffer bevestig beskikbaarheid by jou adres. | Umhlinzeki wakho uqinisekisa ukutholakala ekhelini lakho. |
| `signupAddressLabel` | Installation address | Installasie-adres | Ikheli lokufakwa |
| `signupAddressRequired` | Enter the installation address. | Voer die installasie-adres in. | Faka ikheli lokufakwa. |
| `signupTermsLabel` | I accept the terms and conditions | Ek aanvaar die bepalings en voorwaardes | Ngiyayamukela imigomo nezimo |
| `signupTermsRequired` | Accept the terms to continue. | Aanvaar die bepalings om voort te gaan. | Yamukela imigomo ukuze uqhubeke. |
| `signupSubmit` | Sign up | Skryf in | Bhalisa |
| `signupSubmitting` | Signing up… | Skryf tans in… | Iyabhalisa… |
| `signupDoneTitle` | You are signed up | Jy is ingeskryf | Usubhalisiwe |
| `signupDoneInvoice` | First invoice {number}: {amount}, due {date} | Eerste faktuur {number}: {amount}, betaalbaar {date} | Inxephezelo yokuqala {number}: {amount}, kufanele ikhokhwe ngo-{date} |
| `signupPayNow` | Pay now | Betaal nou | Khokha manje |
| `signupPayLater` | Pay later | Betaal later | Khokha kamuva |
| `signupInstallationNote` | After you pay, your provider arranges the installation with you. | Nadat jy betaal het, reël jou verskaffer die installasie met jou. | Ngemva kokuthi ukhokhe, umhlinzeki wakho uzohlela ukufakwa nawe. |
| `signupIdCheckNote` | This plan needs an ID check before it can start. | Hierdie pakket benodig 'n ID-kontrole voordat dit kan begin. | Leli phakheji lidinga ukuhlolwa kwe-ID ngaphambi kokuthi liqale. |
| `signupAccountClosed` | Your account is closed. Contact your provider. | Jou rekening is gesluit. Kontak jou verskaffer. | I-akhawunti yakho ivaliwe. Xhumana nomhlinzeki wakho. |
