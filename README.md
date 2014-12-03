# Drexp

## Description
Drexp is a tool to export content from a drupal 6 database to a json file.

Since i looked for a way to export content from a Drupal instance and didn't find any suitable tool, i created this one. It's not very flexible since I only created it to fit my one time need but it's out there if you ever need it.

I'm not so fond of php either so i made it using node.

## Usage
  * Install Nodejs.
  * Install coffeescript:  
  `npm install -g coffee-script`
  * Install npm dependencies:  
  `npm install`
  * Create your local config file:  
  `cp config/local.json.dist config/local.json`
  * Set the appropriate configuration in `local.json`.
  * run the script:  
  `coffee drexp.coffee`
  * If all goes well, you'll find a `result.json` file your working directory.

## License
[GPLv2](http://www.gnu.org/licenses/gpl-2.0.html) or later.

## Contributing
Just head to the github repo: [https://github.com/nleclerc/drexp](https://github.com/nleclerc/drexp)
