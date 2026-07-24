/**
 * WCAG 2 contrast math, mirroring ColorContrast on the server. Used by the
 * general settings page to warn about unreadable brand colour combinations.
 */
window.App.Utils.Contrast = (function () {
    function relativeLuminance(hex) {
        hex = hex.replace('#', '');

        if (hex.length === 3) {
            hex = hex
                .split('')
                .map((character) => character + character)
                .join('');
        }

        const channels = [0, 2, 4].map((offset) => {
            const channel = parseInt(hex.substr(offset, 2), 16) / 255;
            return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
        });

        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
    }

    function ratio(hexA, hexB) {
        const luminanceA = relativeLuminance(hexA);
        const luminanceB = relativeLuminance(hexB);
        const brightest = Math.max(luminanceA, luminanceB);
        const darkest = Math.min(luminanceA, luminanceB);

        return Math.round(((brightest + 0.05) / (darkest + 0.05)) * 100) / 100;
    }

    return {
        ratio,
        AA_NORMAL: 4.5,
    };
})();
