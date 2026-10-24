# Add this project to GitHub

## 1. Review the files

From the repository root, make sure the folders `migrations`, `fixtures`, `tests`, and `docs` are present. Read `README.md` and `docs/design.md` before publishing. The implementation uses a representative internship-management brief; confirm the business rules with your internship mentor.

## 2. Create an empty GitHub repository

On GitHub, create a repository with a name such as `business-rules-relational-model`. For a first push, it is easiest to create it without initializing another README, license, or `.gitignore`, since those are already in this folder.

## 3. Initialize and push from PowerShell

Open PowerShell in the folder containing this `README.md`. Run:

```powershell
git --version
```

If Git is installed, continue:

```powershell
git init
git add .
git status
git commit -m "Add internship management relational model and SQL tests"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

Replace `YOUR-USERNAME` and `YOUR-REPOSITORY` with the values from your GitHub repository page. Do not type those placeholder words literally. If an `origin` remote is already configured, inspect it with `git remote -v` instead of adding it again.

## 4. Verify the repository online

After pushing, open the repository page and check that:

- the README appears on the home page;
- the Mermaid ER diagram renders in `docs/er-diagram.md`;
- the SQL migration, fixtures, and test scripts are visible;
- `docs/test-results.md` records the output that was actually observed;
- no passwords, `.env` files, personal data, or database dumps were committed.

## 5. If Git is not installed

Install Git for Windows from [git-scm.com](https://git-scm.com/download/win), reopen PowerShell, and repeat the commands above. You can also upload the repository files using GitHub's web interface, but Git is more convenient for future changes.
