##- NPM related
#NPM plain english aliases
alias buildit='npm run build';
alias watchit='npm run watch';
alias rebootnpm='rm -rf node_modules/ && rm -rf package-lock.json && npm install && npm audit fix';
alias npm-update='npx npm-check-updates -u';



#fancy conditional statements to homogenize build processes based on context
function dev () {
    if [ -e ./frontity.settings.js ]; then
    npx frontity dev;

    elif [ -e ./gulpfile.js ]; then
    gulp watch;

    elif [ -e ./yarn.lock ]; then
    yarn start;

    elif [ -e ./webpack.config.js ]; then
    npm run build;

    else
    echo "build process unaccounted for. \n \n please update script in zsh-scripts/npm/npm.zsh";
    fi;
}