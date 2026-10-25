require 'spec_helper'

describe 'Website', :js, type: :feature do
  it 'shows introductions, follow-up, and reporting as clear product demonstrations' do
    visit '/'
    expect(page).to have_css('.hero h1', text: 'Meet for coffee.')
    expect(page).to have_css('.hero-preview img[src="/img/sup-dm.png"]')
    find('img[src="/img/sup-ask.png"]').execute_script("this.scrollIntoView({block: 'center'})")
    expect(page).to have_css('.followup-preview img[src="/img/sup-ask.png"]') do |image|
      image.evaluate_script('this.complete && this.naturalWidth > 0 && this.width === this.naturalWidth / 2')
    end
    find('.reporting-preview').execute_script("this.scrollIntoView({block: 'center'})")
    expect(page).to have_css('.reporting-preview img[src="/img/sup-stats.png"]') do |image|
      image.evaluate_script('this.complete && this.naturalWidth > 0 && this.width <= this.naturalWidth / 2')
    end
  end

  it 'explains triads with a real introduction before the follow-up section' do
    visit '/'
    expect(page).to have_css('section[aria-labelledby="solution-title"] + section[aria-labelledby="followup-title"]')
    expect(page).to have_css('#solution-title', text: "You haven't tried 3.")
    find('.solution-preview').execute_script("this.scrollIntoView({block: 'center'})")
    expect(page).to have_css('.solution-preview img[src="/img/sup-triad.png"]') do |image|
      image.evaluate_script('this.complete && this.naturalWidth > 0 && this.width <= this.naturalWidth / 2')
    end
  end

  it 'expands and collapses help with the keyboard' do
    visit '/help.html'
    within('details', text: 'How do I opt out or opt back in?') do
      expect(page).to have_no_css('p')
      find('summary').send_keys(:enter)
      expect(page).to have_css('p', text: 'opt out')
      find('summary').send_keys(:enter)
      expect(page).to have_no_css('p')
    end
  end

  it 'keeps navigation usable at 320 pixels' do
    visit '/'
    page.execute_script("document.body.innerHTML = '<iframe id=\"mobile\" title=\"Mobile\" src=\"/\" width=\"320\" style=\"border:0\"></iframe>'")
    within_frame('mobile') do
      find('.reporting-preview').execute_script("this.scrollIntoView({block: 'center'})")
      expect(page).to have_css('.reporting-preview img') do |image|
        image.evaluate_script('this.complete && this.naturalWidth > 0 && this.width <= this.naturalWidth / 2')
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      expect(find('.reporting-preview').evaluate_script('this.scrollWidth <= this.clientWidth')).to be true
      within('nav') { click_link 'Help' }
      expect(page).to have_css('h1', text: "S'Up: Help")
    end
  end

  it 'preserves the privacy policy in the shared layout' do
    visit '/privacy.html'
    expect(page).to have_css('main h1', text: "S'Up for Slack Teams Privacy Policy")
    expect(page).to have_link('Google API Services User Data Policy')
    expect(page).to have_link('Pricing', href: '/#pricing')
  end
end
