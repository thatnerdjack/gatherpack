// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

FontAwesome.config.mutateApproach = 'sync'
import "trix"
import "@rails/actiontext"

import "font_awesome"
import "code_editor"

const wireFancyColorInputs = root => {
    root.querySelectorAll('.fancy-color-container input[type="color"]').forEach(elem => {
        elem.addEventListener("input", ev => {
            ev.target.parentElement.nextElementSibling.firstChild.value = ev.target.value
        });
    });

    root.querySelectorAll('.fancy-color-container input[type="text"]').forEach(elem => {
        elem.addEventListener("input", ev => {
            ev.target.parentElement.previousElementSibling.firstChild.value = ev.target.value
        });
        elem.value = elem.parentElement.previousElementSibling.firstChild.value
    });
}

document.addEventListener("turbo:load", ev => wireFancyColorInputs(document))
// Forms fetched into a turbo frame — remote modals — never fire turbo:load.
document.addEventListener("turbo:frame-load", ev => wireFancyColorInputs(ev.target))
