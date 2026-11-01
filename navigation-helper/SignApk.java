import com.android.apksig.ApkSigner;
import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.List;

class SignApk {
    public static void main(String[] args) throws Exception {
        KeyStore store = KeyStore.getInstance("PKCS12");
        char[] password = "local-build-only".toCharArray();
        try (var input = new FileInputStream(args[0])) { store.load(input, password); }
        var signer = new ApkSigner.SignerConfig.Builder("navigation-helper",
            (PrivateKey) store.getKey("navigation-helper", password),
            List.of((X509Certificate) store.getCertificate("navigation-helper"))).build();
        new ApkSigner.Builder(List.of(signer))
            .setInputApk(new File(args[1]))
            .setOutputApk(new File(args[2]))
            .setMinSdkVersion(23)
            .setV1SigningEnabled(true)
            .setV2SigningEnabled(true)
            .build().sign();
    }
}
