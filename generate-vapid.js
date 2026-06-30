const webpush = require('web-push');

try {
  console.log('Génération des clés VAPID en cours...');
  const vapidKeys = webpush.generateVAPIDKeys();
  console.log('\n================================================================');
  console.log('VAPID PUBLIC KEY (À mettre dans VITE_VAPID_PUBLIC_KEY et VAPID_PUBLIC_KEY) :');
  console.log(vapidKeys.publicKey);
  console.log('================================================================');
  console.log('VAPID PRIVATE KEY (À mettre dans VAPID_PRIVATE_KEY) :');
  console.log(vapidKeys.privateKey);
  console.log('================================================================\n');
  console.log('Copiez et collez ces clés dans vos fichiers .env correspondants !');
} catch (err) {
  console.error('Erreur lors de la génération. Assurez-vous d\'exécuter "npm install" au préalable.');
}
