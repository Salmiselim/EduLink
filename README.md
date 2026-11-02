EduLink - backend (serverless)

===

This branch contains ONLY the serverless backend: Firestore security rules, composite indexes and Cloud Functions.

Deploy (requires firebase login + Blaze plan for functions):

  firebase deploy --only firestore:rules,firestore:indexes
  firebase deploy --only functions

Project: edulink-57f43
