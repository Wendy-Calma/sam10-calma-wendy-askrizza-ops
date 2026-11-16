#!/bin/bash
# Scans user-typed messages in MongoDB for email addresses and phone numbers
# (the personal data most likely to be sent on to the model provider).
# Prints counts and masked samples only. Exit code 1 if anything is found.
set -euo pipefail
docker exec chat-mongodb mongosh --quiet LibreChat --eval '
const checks = {
  email: /[A-Za-z0-9._%+-]+@(?!rizza\.example)[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
  phone: /(\+?\d[\d ()-]{8,}\d)/
};
const mask = s => s.replace(/[A-Za-z0-9]/g, (c, i) => (i % 3 ? "*" : c));
let found = 0;
const total = db.messages.countDocuments({ isCreatedByUser: true });
for (const [name, re] of Object.entries(checks)) {
  const hits = db.messages.find({ isCreatedByUser: true, text: { $regex: re } }, { text: 1 }).toArray();
  found += hits.length;
  print(`${name}: ${hits.length} message(s)`);
  hits.slice(0, 3).forEach(m => print("  e.g. " + mask(m.text.match(re)[0])));
}
print(`scanned ${total} user message(s) at ${new Date().toISOString()}: ${found ? "PERSONAL DATA FOUND" : "clean"}`);
quit(found ? 1 : 0);
'
