// Main JavaScript file for the documentation site

// Function to toggle primary sections
function togglePrimarySection(header) {
    const content = header.nextElementSibling;
    const toggle = header.querySelector('.collapse-toggle');
    
    if (header.classList.contains('collapsed')) {
        // Expand
        header.classList.remove('collapsed');
        content.classList.remove('collapsed');
        toggle.textContent = '▼';
    } else {
        // Collapse
        header.classList.add('collapsed');
        content.classList.add('collapsed');
        toggle.textContent = '▶';
    }
}

// Initialize the page when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Set the content area to fill available space
    adjustContentHeight();
    
    // Listen for window resize to adjust content height
    window.addEventListener('resize', adjustContentHeight);
});

// Function to adjust content area height - improved approach
function adjustContentHeight() {
    const header = document.querySelector('.site-header');
    const topNav = document.querySelector('.top-nav');
    const footer = document.querySelector('.site-footer');
    
    if (header && footer) {
        const headerHeight = header.offsetHeight;
        const topNavHeight = topNav ? topNav.offsetHeight : 0;
        const footerHeight = footer.offsetHeight;
        
        // Calculate total header height including the top navigation
        const totalHeaderHeight = headerHeight + topNavHeight;
        
        // Update CSS variables for layout calculations
        document.documentElement.style.setProperty('--site-header-height', headerHeight + 'px');
        document.documentElement.style.setProperty('--header-height', totalHeaderHeight + 'px');
        document.documentElement.style.setProperty('--footer-height', footerHeight + 'px');
        
        // Ensure the page content is positioned correctly
        const pageContent = document.querySelector('.page-content');
        if (pageContent) {
            pageContent.style.top = totalHeaderHeight + 'px';
        }
    }
}
