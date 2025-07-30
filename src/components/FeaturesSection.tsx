import { Card } from "@/components/ui/card";
import { Monitor, Smartphone, Wine, Globe, Zap, Shield } from "lucide-react";

const FeaturesSection = () => {
  const features = [
    {
      icon: Monitor,
      title: "Ubuntu 24.04 + KDE Plasma",
      description: "Full-featured, modern desktop environment with complete Linux application support"
    },
    {
      icon: Smartphone,
      title: "Android Apps (Waydroid)",
      description: "Run APKs in a containerized Android environment directly in your browser"
    },
    {
      icon: Wine,
      title: "Windows Applications",
      description: "Execute .exe applications using Wine with PlayOnLinux integration"
    },
    {
      icon: Globe,
      title: "Web-Based Access",
      description: "Access desktop, terminal, and applications from any modern web browser"
    },
    {
      icon: Zap,
      title: "Zero Dependencies",
      description: "No host-side configuration required - just Docker and you're ready to go"
    },
    {
      icon: Shield,
      title: "Software Rendering",
      description: "Mesa with llvmpipe for OpenGL rendering, no GPU required on the host"
    }
  ];

  return (
    <div className="py-24 px-6 bg-secondary/20">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold mb-4">Powerful Features</h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Everything you need for a complete cloud desktop experience
          </p>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => {
            const IconComponent = feature.icon;
            return (
              <Card key={index} className="bg-card border-border shadow-card hover:shadow-elevated transition-all duration-300 p-6 group">
                <div className="space-y-4">
                  <div className="p-3 bg-primary/10 rounded-lg w-fit group-hover:bg-primary/20 transition-colors">
                    <IconComponent className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="text-lg font-semibold text-card-foreground">{feature.title}</h3>
                  <p className="text-muted-foreground text-sm leading-relaxed">{feature.description}</p>
                </div>
              </Card>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default FeaturesSection;