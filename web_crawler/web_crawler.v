import net.http
import net.html

fn main() {
	config := http.FetchConfig{
		user_agent: 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0'
	}

	resp := http.fetch(http.FetchConfig{ ...config, url: 'https://modules.vlang.io/index.html' }) or {
		println('failed to fetch data from the server')
		return
	}

	mut doc := html.parse(resp.body)
	tags := doc.get_tag_by_attribute_value('class', 'menu-row')
	for tag in tags {
		el := tag.children[0]
		href := el.attributes['href'] or { "none"}
		title := el.text()

		println('href: ${href}')
		println('title: ${title}')
		println('')
	}
}