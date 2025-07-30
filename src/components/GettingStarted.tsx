import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Copy, Download, Play, Settings } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

const GettingStarted = () => {
  const { toast } = useToast();

  const steps = [
    {
      step: "1",
      title: "Prerequisites",
      description: "Install Docker and Docker Compose on your system",
      code: "# Install Docker\ncurl -fsSL https://get.docker.com -o get-docker.sh\nsh get-docker.sh",
      icon: Download
    },
    {
      step: "2", 
      title: "Configuration",
      description: "Create and configure your environment file",
      code: "cp .env.example .env\n# Edit .env with your settings",
      icon: Settings
    },
    {
      step: "3",
      title: "Build & Run",
      description: "Start the containerized desktop environment",
      code: "docker compose up -d",
      icon: Play
    }
  ];

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast({
      title: "Copied to clipboard",
      description: "Command copied successfully",
    });
  };

  return (
    <div className="py-24 px-6">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold mb-4">Getting Started</h2>
          <p className="text-xl text-muted-foreground">
            Get your cloud desktop running in three simple steps
          </p>
        </div>
        
        <div className="space-y-8">
          {steps.map((step, index) => {
            const IconComponent = step.icon;
            return (
              <Card key={index} className="bg-gradient-card border-border shadow-card p-6">
                <div className="flex flex-col lg:flex-row gap-6">
                  <div className="flex items-start space-x-4 lg:min-w-[300px]">
                    <Badge className="bg-primary text-primary-foreground font-bold text-lg px-3 py-1">
                      {step.step}
                    </Badge>
                    <div className="space-y-2">
                      <div className="flex items-center space-x-2">
                        <IconComponent className="w-5 h-5 text-primary" />
                        <h3 className="text-lg font-semibold text-card-foreground">{step.title}</h3>
                      </div>
                      <p className="text-muted-foreground text-sm">{step.description}</p>
                    </div>
                  </div>
                  
                  <div className="flex-1">
                    <div className="relative bg-muted/30 rounded-lg p-4 border border-border">
                      <pre className="text-sm text-foreground font-mono overflow-x-auto">
                        <code>{step.code}</code>
                      </pre>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="absolute top-2 right-2"
                        onClick={() => copyToClipboard(step.code)}
                      >
                        <Copy className="w-4 h-4" />
                      </Button>
                    </div>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
        
        <div className="mt-12 text-center">
          <Card className="bg-gradient-card border-border shadow-card p-6 inline-block">
            <div className="flex items-center space-x-4">
              <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
              <span className="text-card-foreground font-medium">
                After starting, access your services at the URLs shown above
              </span>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default GettingStarted;