import com.android.apksig.ApkVerifier;
import java.io.File;
import java.security.MessageDigest;
import java.util.HexFormat;

class VerifyApk {
    public static void main(String[] args) throws Exception {
        var result = new ApkVerifier.Builder(new File(args[0]))
            .setMinCheckedPlatformVersion(27).setMaxCheckedPlatformVersion(27).build().verify();
        if (!result.isVerified()) throw new IllegalStateException("APK verification failed: " + result.getErrors());
        if (result.getSignerCertificates().size() != 1) throw new IllegalStateException("Expected one signer");
        String fingerprint = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
            .digest(result.getSignerCertificates().get(0).getEncoded()));
        if (args.length > 1 && !fingerprint.equalsIgnoreCase(args[1])) throw new IllegalStateException("Unexpected APK signer");
        System.out.println("APK verified for Android 8.1; signer SHA-256=" + fingerprint);
    }
}
