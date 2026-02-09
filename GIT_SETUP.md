# Git setup & minimal private repo instructions

To create a private GitHub repository and push this suite (local steps):

```powershell
git init
git add .
git commit -m "Initial RadioRegression suite"
git branch -M main
# set remote to the private repo URL you create on GitHub
git remote add origin <repo-url>
git push -u origin main
```

Add a collaborator via GitHub settings (Settings → Collaborators):

- Add: `mirandalelo` (Leandro Lourenço Miranda)

Recommended `.gitignore` entries (this repo already includes `.gitignore`):

```
artifacts/
.maestro/tests/
.maestro/screenshots/
*.mp4
*.log
```

If your organization requires internal hosting, keep the repo private and treat it as a shareable PoC snapshot only.
