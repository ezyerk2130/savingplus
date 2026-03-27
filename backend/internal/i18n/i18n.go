package i18n

// Messages contains common application messages in English and Swahili.
var Messages = map[string]map[string]string{
	"welcome":              {"en": "Welcome", "sw": "Karibu"},
	"deposit_success":      {"en": "Deposit initiated successfully", "sw": "Amana imeanzishwa kwa mafanikio"},
	"withdrawal_success":   {"en": "Withdrawal initiated successfully", "sw": "Kutoa fedha kumeanzishwa kwa mafanikio"},
	"insufficient_balance": {"en": "Insufficient balance", "sw": "Salio haitoshi"},
	"savings_created":      {"en": "Savings plan created", "sw": "Mpango wa akiba umeundwa"},
	"kyc_required":         {"en": "KYC verification required", "sw": "Uthibitishaji wa KYC unahitajika"},
	"login_success":        {"en": "Login successful", "sw": "Umefanikiwa kuingia"},
	"otp_sent":             {"en": "OTP sent successfully", "sw": "OTP imetumwa kwa mafanikio"},
	"password_changed":     {"en": "Password changed successfully", "sw": "Neno la siri limebadilishwa"},
	"pin_changed":          {"en": "Transaction PIN changed", "sw": "PIN ya muamala imebadilishwa"},
	"loan_applied":         {"en": "Loan application submitted", "sw": "Maombi ya mkopo yamewasilishwa"},
	"insurance_subscribed": {"en": "Insurance policy activated", "sw": "Sera ya bima imeanzishwa"},
	"group_created":        {"en": "Savings group created", "sw": "Kikundi cha akiba kimeundwa"},
	"contribution_paid":    {"en": "Contribution paid", "sw": "Mchango umelipwa"},
}

// T returns the translated message for the given key and language.
// Falls back to English if the requested language is not available.
// Returns the key itself if no translation exists.
func T(key, lang string) string {
	if msgs, ok := Messages[key]; ok {
		if msg, ok := msgs[lang]; ok {
			return msg
		}
		if msg, ok := msgs["en"]; ok {
			return msg
		}
	}
	return key
}
