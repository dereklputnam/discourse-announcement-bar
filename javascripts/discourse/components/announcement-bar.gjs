import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { htmlSafe } from '@ember/template';
import cookie, { removeCookie } from 'discourse/lib/cookie';
import { defaultHomepage } from 'discourse/lib/utilities';
import icon from 'discourse-common/helpers/d-icon';
import and from 'truth-helpers/helpers/and';

export default class AnnouncementBar extends Component {
  @service site;
  @service siteSettings;
  @service router;
  @tracked closed = false;

  <template>
    {{#if (and this.showOnRoute this.showOnMobile this.cookieState this.showInCategories)}}
      <div class='announcement-bar__wrapper {{settings.plugin_outlet}}'>

        <div class='announcement-bar__container'>
          <div class='announcement-bar__content'>
            <span>{{htmlSafe settings.bar_text}}</span>
            {{#if settings.show_button}}
              <a
                class='btn btn-primary'
                href='{{settings.button_link}}'
                target='{{settings.button_target}}'
              >{{settings.button_text}}
              </a>
            {{/if}}
          </div>
          {{#if settings.dismissable}}
            <div class='announcement-bar__close'>
              <a {{on 'click' this.closeBanner}}>
                {{icon 'xmark'}}
              </a>
            </div>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>

  get showOnRoute() {
    const currentRoute = this.router.currentRouteName;
    switch (settings.show_on) {
      case 'everywhere':
        return !currentRoute.includes('admin');
      case 'homepage':
        return currentRoute === `discovery.${defaultHomepage()}`;
      case 'latest/top/new/categories':
        const topMenu = this.siteSettings.top_menu;
        const targets = topMenu.split('|').map((opt) => `discovery.${opt}`);
        return targets.includes(currentRoute);
      case 'specific categories':
        return !currentRoute.includes('admin');
      default:
        return false;
    }
  }

  parseListSetting(value) {
    const str = Array.isArray(value) ? value.join(',') : value;
    return str.split(',').map((s) => s.trim()).filter(Boolean);
  }

  get showInCategories() {
    if (settings.show_on !== 'specific categories') return true;

    const allowed = this.parseListSetting(settings.show_in_categories);
    if (!allowed.length) return true;

    let route = this.router.currentRoute;
    while (route) {
      const slug = route.params?.categorySlug || route.params?.category_slug;
      if (slug) {
        const category = this.site.categories.find((c) => c.slug === slug);
        if (!category) return false;
        return allowed.includes(String(category.id)) || allowed.includes(category.slug);
      }
      route = route.parent;
    }
    return false;
  }

  get showOnMobile() {
    if (settings.hide_on_mobile && this.site.mobileView) {
      return false;
    } else {
      return true;
    }
  }

  get cookieExpirationDate() {
    return moment().add(1, 'year').toDate();
  }

  get cookieState() {
    if (!settings.dismissable) return true;
    const closed_cookie = cookie('discourse_announcement_bar_closed');
    if (closed_cookie) {
      const cookieValue = JSON.parse(closed_cookie);
      if (cookieValue.name !== settings.update_version) {
        removeCookie('discourse_announcement_bar_closed', { path: '/' });
      } else {
        this.closed = true;
      }
    }
    return !this.closed;
  }

  @action
  closeBanner() {
    this.closed = true;
    const bannerState = { name: settings.update_version, closed: 'true' };
    cookie('discourse_announcement_bar_closed', JSON.stringify(bannerState), {
      expires: this.cookieExpirationDate,
      path: '/',
    });
  }
}
