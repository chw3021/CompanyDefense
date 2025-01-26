//package io.github.chw3021.companydefense.android.firebase;
//
//import com.google.firebase.auth.FirebaseAuth;
//import com.google.firebase.database.DatabaseReference;
//import com.google.firebase.database.FirebaseDatabase;
//
//import io.github.chw3021.companydefense.firebase.FirebaseService;
//import io.github.chw3021.companydefense.firebase.FirebaseCallback;
//
//public class AndroidFirebaseService implements FirebaseService {
//    private final FirebaseAuth auth;
//    private final FirebaseDatabase database;
//
//    public AndroidFirebaseService() {
//        auth = FirebaseAuth.getInstance();
//        database = FirebaseDatabase.getInstance();
//    }
//
//    @Override
//    public <T> void fetchData(String path, Class<T> type, FirebaseCallback<T> callback) {
//        DatabaseReference ref = database.getReference(path);
//        ref.get().addOnSuccessListener(snapshot -> {
//            T data = snapshot.getValue(type);
//            callback.onSuccess(data);
//        }).addOnFailureListener(callback::onFailure);
//    }
//
//    @Override
//    public <T> void saveData(String path, T data, FirebaseCallback<Void> callback) {
//        DatabaseReference ref = database.getReference(path);
//        ref.setValue(data).addOnSuccessListener(aVoid -> callback.onSuccess(null))
//                .addOnFailureListener(callback::onFailure);
//    }
//
//    @Override
//    public void login(String email, String password, FirebaseCallback<Void> callback) {
//        auth.signInWithEmailAndPassword(email, password)
//                .addOnSuccessListener(authResult -> callback.onSuccess(null))
//                .addOnFailureListener(callback::onFailure);
//    }
//
//    @Override
//    public void logout() {
//        auth.signOut();
//    }
//
//    @Override
//    public String getCurrentUserId() {
//        if (auth.getCurrentUser() != null) {
//            return auth.getCurrentUser().getUid();
//        }
//        return null;
//    }
//}
