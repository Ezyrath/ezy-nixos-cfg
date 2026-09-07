#!/usr/bin/env bash

set -e

# Helper: ask a y/n question, default is "no"
ask_yes_no() {
	local prompt="$1"
	local answer
	read -r -p "$prompt (y/N): " answer
	[ "$answer" == "y" ] || [ "$answer" == "Y" ]
}

# Track plaintext temp files so they're wiped even if the script exits early
TMP_FILES=()
cleanup_tmp_files() {
	[ "${#TMP_FILES[@]}" -eq 0 ] || rm -f "${TMP_FILES[@]}"
}
trap cleanup_tmp_files EXIT

# ---------------------------------------------------------------------------
# 1. Ensure deploy/ layout exists and SOPS age key is present
# ---------------------------------------------------------------------------
KEY_DIR="deploy/persist/var/lib/sops"
KEY_FILE="$KEY_DIR/key.age"
mkdir -p "$KEY_DIR"

if ! command -v age-keygen &>/dev/null; then
	echo "Error: age-keygen is not installed."
	exit 1
fi

GENERATE_KEY=true
if [ -f "$KEY_FILE" ]; then
	GENERATE_KEY=false
	if ask_yes_no "Warning: $KEY_FILE already exists. Overwrite it?"; then
		GENERATE_KEY=true
	fi
fi

if [ "$GENERATE_KEY" == true ]; then
	chmod u+w "$KEY_FILE" 2>/dev/null || true
	age-keygen >"$KEY_FILE"
	chmod 0400 "$KEY_FILE"
	echo "Generated new SOPS age key at $KEY_FILE"

	# Only offer to overwrite the system key on the host itself (repo checked
	# out at /etc/nixos) since that's the only place the system key path is meaningful.
	SYSTEM_KEY_FILE="/persist/var/lib/sops/key.age"
	if [ "$(realpath .)" == "/etc/nixos" ] && ask_yes_no "Do you also want to overwrite the system key ($SYSTEM_KEY_FILE)?"; then
		sudo install -o root -g root -m 0400 "$KEY_FILE" "$SYSTEM_KEY_FILE"
		echo "System key updated at $SYSTEM_KEY_FILE."
	fi
fi

SOPS_AGE_KEY_FILE="$(pwd)/$KEY_FILE"
export SOPS_AGE_KEY_FILE

# ---------------------------------------------------------------------------
# 2. Generate .sops.yaml from the age key's public key
# ---------------------------------------------------------------------------
AGE_PUBLIC_KEY=$(age-keygen -y "$KEY_FILE")

cat >.sops.yaml <<EOF
keys:
  - &admin_key $AGE_PUBLIC_KEY
creation_rules:
  - path_regex: secrets/.*\.yaml\$
    key_groups:
      - age:
          - *admin_key
EOF

echo "Wrote .sops.yaml (public key: $AGE_PUBLIC_KEY)"

# ---------------------------------------------------------------------------
# 3. Optionally generate a secret file (workstation or server)
# ---------------------------------------------------------------------------
if ask_yes_no "Do you want to generate a secret file?"; then
	if ! command -v sops &>/dev/null; then
		echo "Error: sops is not installed."
		exit 1
	fi
	if ! command -v mkpasswd &>/dev/null; then
		echo "Error: mkpasswd is not installed."
		exit 1
	fi

	SECRET_TYPES=(workstation server)
	echo "Secret file type:"
	for i in "${!SECRET_TYPES[@]}"; do
		echo "  $((i + 1))) ${SECRET_TYPES[$i]}"
	done

	SECRET_TYPE=""
	while [ -z "$SECRET_TYPE" ]; do
		read -r -p "Choose a number: " CHOICE
		if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#SECRET_TYPES[@]}" ]; then
			SECRET_TYPE="${SECRET_TYPES[$((CHOICE - 1))]}"
		fi
	done

	mkdir -p secrets
	SECRET_PATH="secrets/$SECRET_TYPE.yaml"

	GENERATE_SECRET=true
	if [ -f "$SECRET_PATH" ]; then
		GENERATE_SECRET=false
		if ask_yes_no "Warning: $SECRET_PATH already exists. Overwrite it?"; then
			GENERATE_SECRET=true
		fi
	fi

	if [ "$GENERATE_SECRET" == true ]; then
		# Ask for password
		while true; do
			read -rs -p "Enter ezyrath_password: " PASS1
			echo
			read -rs -p "Confirm ezyrath_password: " PASS2
			echo
			if [ "$PASS1" == "$PASS2" ]; then
				break
			else
				echo "Passwords do not match. Try again."
			fi
		done

		HASHED_PASS=$(mkpasswd -m sha-512 "$PASS1")

		# Initialize YAML content in a temp file
		TEMP_YAML=$(mktemp)
		TMP_FILES+=("$TEMP_YAML")
		echo "ezyrath_password: $HASHED_PASS" >"$TEMP_YAML"

		# k0s secrets only make sense for server secret files
		if [ "$SECRET_TYPE" == "server" ] && ask_yes_no "Is k0s used for this secret file?"; then
			KEEPALIVED_PASS=$(openssl rand -base64 32)
			echo "k0s_keepalived_pass: $KEEPALIVED_PASS" >>"$TEMP_YAML"

			if ask_yes_no "Do you want to add a k0s join token?"; then
				TOKEN_TMP=$(mktemp)
				TMP_FILES+=("$TOKEN_TMP")
				echo "# Paste your k0s join token here. Save and quit." >"$TOKEN_TMP"

				# Open editor (default to vim)
				${EDITOR:-vim} "$TOKEN_TMP"

				# Read content, removing comments
				JOIN_TOKEN=$(grep -v '^#' "$TOKEN_TMP" | tr -d '\n')

				echo "k0s_join_token: $JOIN_TOKEN" >>"$TEMP_YAML"

				rm -f "$TOKEN_TMP"
			else
				echo "k0s_join_token: \"\"" >>"$TEMP_YAML"
			fi
		fi

		echo "Encrypting and saving to $SECRET_PATH..."
		# Use --filename-override so sops matches the rule for the target file, not the temp file
		# shellcheck disable=SC2094 # --filename-override only uses the path as a string, sops never reads it
		sops --encrypt --filename-override "$SECRET_PATH" "$TEMP_YAML" >"$SECRET_PATH"

		rm -f "$TEMP_YAML"

		echo "Done. Secret file created at $SECRET_PATH"
	fi
fi

# ---------------------------------------------------------------------------
# 4. Generate initrd SSH key
# ---------------------------------------------------------------------------
INITRD_KEY="secrets/initrd_ssh_key"

if ! command -v ssh-keygen &>/dev/null; then
	echo "Error: ssh-keygen is not installed."
	exit 1
fi

GENERATE_INITRD_KEY=true
if [ -f "$INITRD_KEY" ]; then
	GENERATE_INITRD_KEY=false
	if ask_yes_no "Warning: $INITRD_KEY already exists. Overwrite it?"; then
		GENERATE_INITRD_KEY=true
	fi
fi

if [ "$GENERATE_INITRD_KEY" == true ]; then
	mkdir -p secrets
	rm -f "$INITRD_KEY" "$INITRD_KEY.pub"
	ssh-keygen -t ed25519 -N "" -f "$INITRD_KEY" -C "initrd-host-key"
	echo "Generated initrd SSH key at $INITRD_KEY"
fi

echo "All done."
