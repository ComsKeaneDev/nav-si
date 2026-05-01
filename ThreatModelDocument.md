
This is a document that defines the potential security risks to the Nav-Si application, where the risks are categorised into high, medium, and low. It also gives mitigations for the threats, so that any new features can be checked against this document before being added to the deployed app.

# High
## Threat 1: Video stream interception
This is where an attacker intercepts the video at any point of the transit (camera -> phone, camera -> server, server -> phone). If the stream is unencrypted (or weakly encrypted) an attacker can reveal real world sensitive information.

### Impact:
If plaintext is recovered, complete breach of user's privacy and in some cases serious security concerns if the attacker uses the data for more malicious activities (e.g. tracking the user based on daily routes).

### Likelihood:
* At home: Low - unless the home router is compromised, all actors on the network can be trusted reducing the risk of malicious activity.
* In public: Medium - public Wi-Fi networks are more likely to be compromised, increasing the risk of a malicious actor attempting to gather personal information

### Mitigations:
* Use TLS 1.3 as minimum security every time data is in transit
* Certificate pinning to ensure data is being sent to the correct server.

### Risk after mitigations:
Low - as long as certificate pinning and encryption is implemented correctly (using trusted libraries) information should not be vulnerable.

## Threat 2: Camera-Phone pairing spoofed
Attacker intercepts and/or replays initial pairing of devices letting the attacker gather all the data normally sent between the devices.

### Impact:
If attacker can spoof the device identity, all privacy is compromised as all data could be redirected to the attacker.

### Likelihood:
* High - if pairing is done in public or on an insecure channel spoofing is very easy and likely to be exploited

### Mitigations:
* Only allow pairing with QR-codes meaning the attacker would need to be physically close enough to scan code in order to spoof.
* Use ECDH to agree a shared secret which would be harder to spoof than a simple numeric ID
* Server validates app signature on *every* new session.
* Short lived tokens to reduce the amount of sessions that the spoofed identity could be used on.

### Risk after mitigations:
Low - unless the attacker is physically present during the initial pairing, spoofing shouldn't be possible. Even if the attacker does spoof the pairing, the shared secret won't last long as it will be refreshed regularly.

## Threat 3: Firmware tampered with during OTA update
This is where an attacker pushes malicious firmware to camera exploiting the OTA update capabilities. 

### Impact:
If the firmware is successfully updated to a malicious version, this could lead to the camera sending data to the attacker as well as/instead of the phone/server. This would completely compromise the user's privacy.

### Likelihood:
* Medium - if the attacker has access to a camera, and authentication isn't implemented, they could easily upload whatever code they want as the firmware resulting in a compromised camera. Although this would require the attacker to gain access to a camera for long enough to upload a firmware update which could be difficult.

### Mitigations:
* Only accept firmware updates from authenticated server - using a HTTPS secured endpoint and pin the certificate in the camera bootloader
* Verify the firmware signature before flashing old firmware
* ESP32-S3 Secure Boot V2 enabled in production

### Risk after mitigations:
Low - attacker would have to change the bootloader's certificate value to mimic the authenticated server, also the firmware they are installing would have to have a valid signature.## Threat 3: Firmware tampered with during OTA update
This is where an attacker pushes malicious firmware to camera exploiting the OTA update capabilities. 

### Impact:
If the firmware is successfully updated to a malicious version, this could lead to the camera sending data to the attacker as well as/instead of the phone/server. This would completely compromise the user's privacy.

### Likelihood:
* Medium - if the attacker has access to a camera, and authentication isn't implemented, they could easily upload whatever code they want as the firmware resulting in a compromised camera. Although this would require the attacker to gain access to a camera for long enough to upload a firmware update which could be difficult.

### Mitigations:
* Only accept firmware updates from authenticated server - using a HTTPS secured endpoint and pin the certificate in the camera bootloader
* Verify the firmware signature before flashing old firmware
* ESP32-S3 Secure Boot V2 enabled in production

### Risk after mitigations:
Low - attacker would have to change the bootloader's certificate value to mimic the authenticated server, also the firmware they are installing would have to have a valid signature.

## Threat 4: Physical flash extraction
After gaining physical access to the camera, flash is dumped revealing all the important information such as keys, certifications, config.

### Impact:
Credentials (including keys and certs) exposed which attacker could use to impersonate the server and/or the camera device enabling sophisticated MITM attacks.

### Likelihood:
* Medium - hard for the attacker to gain physical access to camera, however, once acquired the dump would be relatively easy.

### Mitigations:
* ESP32-S3 Flash Encryption enabled in production - encrypting the flashed data so that once recovered, the attacker wouldn't be able to obtain any usable information
* Disable the JTAG connector in production devices to remove attack surface
* Device specific key derivation function - if one device is compromised not all devices are

### Risk after mitigations:
Low - even if the attacker does gain physical access *and* is able to dump the flash (even without the JTAG connector) the resulting data would be encrypted and therefore unusable.


# Medium

## Threat 5: Local model swapped for compromised version
Attacker changes the local processing model to a compromised version which could give users erroneous descriptions.
### Impact:
If users are given the wrong descriptions and/or directions, they could be mislead into dangerous situations.
### Likelihood:
* High - APK files for the app could be easily modified and distributed as a rogue app. Especially since the code is open source giving attackers a good understanding of how the app works.

### Mitigations:
* Server side verification of the app's signature ensuring it hasn't been tampered with
* Verify model hash on app start up against a hardcoded example
* If the model hash is incorrect, refuse inference and warn user
* provide checksums for the application so users can check if they have a valid installation

### Risk after mitigations:
Low - since the app is free, users are likely to download the app from either a play store or directly from the GitHub page.


## Threat 6: Credential BFA (Brute Force Attack)
Attacker guesses a lot of device pairing values until one is correct, obtaining the shared secret between device and camera.
### Impact:
Attacker could imitate the devices adn perform sophisticated MITM attacks to receive the data stream from the camera (and make the camera stream video data even when the user has disabled it).

### Likelihood:
* Medium - if IDs are small enough, BFAs could be a very viable way of spoofing the devices.

### Mitigations:
* Using ECDH shared secrets, with a big enough key size, would make BFAs take too long to be viable
* Exponential time-out of ID guesses would make attacks take even longer - again making it no longer a viable attack
* Short lived secrets forcing regular re-pairing and key refreshes.

### Risk after mitigations:
Low - if big enough (>128bits) IDs are used and time-outs are in place, BFAs would take so long to break, that the secrets would likely be refreshed by the time they are broken.


# Low

## Threat 7: Certificate unpinning on rooted device
Attacker bypasses the certificate pinning allowing the attacker to view and decrypt the transmitted data.
### Impact:
Video frames and AI description intercepted. Also could edit the responses from the server to the device (MITM attack).

### Likelihood:
* High - easy for an attacker to bypass simple certificate pinning using tools such as Frida and perform a MITM attack.

### Mitigations:
* Use Android Integrity API and DeviceCheck (iOS) for server-side application checks to confirm the app hasn't been tampered with
* Add root detection warnings
* Have hard-coded certificate checks so that the attacker has to modify the app source code to fully bypass pinning

### Risk after mitigations:
Low - in order for the attacker to fully bypass pinning, they have to modify the source code. If the source code is edited, the server would refuse communication with it.

## Threat 8: Server logs leak user PII or session data
Unnecessary details in server logs could leak user's session data and/or PII if the attacker gains access to said logs.
### Impact:
Privacy breach if logs are accessed and contain PII.

### Likelihood:
* Medium - if server doesn't have good server log hygiene, attackers could access large amounts of logs revealing private information about users.

### Mitigations:
* Highly structured logging with PII scrubbing to remove sensitive information
* Maximum log retention window defined and strictly followed (e.g. 7 days)
* Log only the strictly necessary information

### Risk after mitigations:
Low - if the logs have no sensitive information within them and are removed frequently, attackers don't have a good chance of breaking a user's privacy.
