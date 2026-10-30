import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

String kycIdTypeLabel(AppLocalizations l10n, KycIdType type) => switch (type) {
  KycIdType.saId => l10n.kycIdTypeSaId,
  KycIdType.passport => l10n.kycIdTypePassport,
  KycIdType.companyReg => l10n.kycIdTypeCompanyReg,
};

String kycIdNumberHint(AppLocalizations l10n, KycIdType type) => switch (type) {
  KycIdType.saId => l10n.kycHintSaId,
  KycIdType.passport => l10n.kycHintPassport,
  KycIdType.companyReg => l10n.kycHintCompanyReg,
};
